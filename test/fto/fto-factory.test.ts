import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { Contract } from 'ethers';
import { Status } from '../common/constants';
import { deployContracts, deployERC20Token } from '../common/deployment';
import { createFTO } from './../common/helpers';

describe('FTO Factory test', function () {
  let usdt: Contract;
  let bera: Contract;
  let yexFTOFactory: Contract;
  let yexFTOFacade: Contract;
  let henloDexFactory: Contract;
  let henloDexRouter: Contract;

  let tokenLauncher: SignerWithAddress,
    factoryOwner: SignerWithAddress,
    Alice: SignerWithAddress;

  before('Deploy Contracts', async () => {
    [factoryOwner, tokenLauncher, Alice] = await ethers.getSigners();

    ({
      usdt,
      bera,
      yexFTOFactory,
      yexFTOFacade,
      henloDexFactory,
      henloDexRouter,
    } = await deployContracts());
  });

  it('should deploy contracts correctly', async () => {
    expect(usdt.address).to.be.properAddress;
    expect(yexFTOFactory.address).to.be.properAddress;
    expect(yexFTOFacade.address).to.be.properAddress;
    expect(henloDexFactory.address).to.be.properAddress;
    expect(henloDexRouter.address).to.be.properAddress;
  });

  describe('FTO Factory: Raised Token Function Test', function () {
    it('should add a raised token correctly', async function () {
      const beforeRaisedTokenLen = (await yexFTOFactory.allRaisedTokens())
        .length;
      await yexFTOFactory.addRaisedToken(bera.address);

      const raisedTokens = await yexFTOFactory.allRaisedTokens();
      expect(raisedTokens.length).to.equal(beforeRaisedTokenLen + 1);

      expect(raisedTokens[beforeRaisedTokenLen]).to.equal(bera.address);

      const isAdded = await yexFTOFactory.isRaisedToken(bera.address);
      expect(isAdded).to.be.true;
    });

    it('should not add the same raised token twice', async function () {
      const beforeRaisedTokenLen = (await yexFTOFactory.allRaisedTokens())
        .length;
      await yexFTOFactory.connect(factoryOwner).addRaisedToken(usdt.address);

      const raisedTokens = await yexFTOFactory.allRaisedTokens();
      expect(raisedTokens.length).to.equal(beforeRaisedTokenLen);

      const isAdded = await yexFTOFactory.isRaisedToken(usdt.address);
      expect(isAdded).to.be.true;
    });

    it('should remove a raised token correctly', async function () {
      await yexFTOFactory.connect(factoryOwner).removeRaisedToken(usdt.address);

      const isAdded = await yexFTOFactory.isRaisedToken(usdt.address);
      expect(isAdded).to.be.false;
    });

    it('should only allow the ftoFactory owner to add a raised token', async function () {
      await expect(
        yexFTOFactory.connect(tokenLauncher).addRaisedToken(bera.address),
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('should only allow the ftoFactory owner to remove a raised token', async function () {
      await expect(
        yexFTOFactory.connect(tokenLauncher).removeRaisedToken(bera.address),
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });
  });

  describe('FTO Factory: Create FTO Test', function () {
    before('Add usdt as a raised token.', async () => {
      await yexFTOFactory.addRaisedToken(usdt.address);
    });
    it('should revert if the raised token is not allowed', async function () {
      const mockToken = await deployERC20Token('mock', 'mock');

      await expect(
        createFTO(yexFTOFactory, tokenLauncher, {
          raisedToken: mockToken.address,
          dexRouter: henloDexRouter.address,
        }),
      ).to.revertedWithCustomError(yexFTOFactory, 'NotAllowedRaisedToken');
    });
    it('should create a new FTO pair and return the correct FTO pair address', async function () {
      const beforeFTOPairsLength = await yexFTOFactory.allPairsLength();

      await createFTO(yexFTOFactory, tokenLauncher, {
        raisedToken: usdt.address,
        dexRouter: henloDexRouter.address,
      });

      const newFTOPairsLength = await yexFTOFactory.allPairsLength();
      expect(newFTOPairsLength).to.equal(beforeFTOPairsLength + 1);

      const createdPair = await yexFTOFactory.allPairs(beforeFTOPairsLength);
      expect(createdPair).to.not.equal(ethers.constants.AddressZero);
    });
  });

  describe('FTO Factory: Manage FTO Pair Test', function () {
    let yexFTOPair: Contract;
    before('Create an FTO Pair for Testing', async () => {
      await createFTO(yexFTOFactory, tokenLauncher, {
        raisedToken: usdt.address,
        dexRouter: henloDexRouter.address,
      });

      const ftoPairsLength = await yexFTOFactory.allPairsLength();
      const createdPair = await yexFTOFactory.allPairs(ftoPairsLength - 1);
      yexFTOPair = await ethers.getContractAt('YexFTOPairV2', createdPair);
    });

    it('should pause/resume the FTO pair', async function () {
      const launchedToken = await yexFTOPair.launchedToken();
      await yexFTOFactory
        .connect(factoryOwner)
        .pause(usdt.address, launchedToken);

      expect(await yexFTOPair.FTOState()).to.equal(Status.Paused);
      await expect(
        yexFTOFactory.connect(factoryOwner).pause(usdt.address, launchedToken),
      ).to.revertedWithCustomError(yexFTOPair, 'FTOPairStatusError');

      await yexFTOFactory
        .connect(factoryOwner)
        .resume(usdt.address, launchedToken);
      expect(await yexFTOPair.FTOState()).to.equal(Status.Processing);

      await expect(
        yexFTOFactory.connect(factoryOwner).resume(usdt.address, launchedToken),
      ).to.revertedWithCustomError(yexFTOPair, 'FTOPairStatusError');
    });

    it('should get FTO token launcher', async function () {
      const launchedToken = await yexFTOPair.launchedToken();
      expect(
        await yexFTOFactory.getFTOPairProvider(usdt.address, launchedToken),
      ).to.equal(tokenLauncher.address);
    });
  });
});
