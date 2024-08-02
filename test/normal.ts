import { expect } from 'chai';
import { Contract } from 'ethers';
import { deployContracts } from './deployment';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

describe('FTO Test: Not use custom hooks', function () {
  let usdt: Contract;
  let yexFTOFactory: Contract;
  let yexFTOFacade: Contract;
  let henloDexFactory: Contract;
  let henloDexRouter: Contract;
  let mockToken: Contract;

  let tokenLauncher: SignerWithAddress;
  let factoryOwner: SignerWithAddress;

  before('Deploy Contracts', async () => {
    [factoryOwner, tokenLauncher] = await ethers.getSigners();

    ({ usdt, yexFTOFactory, yexFTOFacade, henloDexFactory, henloDexRouter, mockToken } =
      await deployContracts());

    await yexFTOFactory.batchAddWhiteList([
          tokenLauncher.address
    ]);
  });

  it('should deploy contracts correctly', async () => {
      expect(usdt.address).to.be.properAddress;
      expect(yexFTOFactory.address).to.be.properAddress;
      expect(yexFTOFacade.address).to.be.properAddress;
      expect(henloDexFactory.address).to.be.properAddress;
      expect(henloDexRouter.address).to.be.properAddress;
  });

  describe('Raised Tokens Test', function () {
      it('should return correct raised token address from ftoFactory', async () => {
        const raisedTokens = await yexFTOFactory.allRaisedTokens();
        expect(raisedTokens.length).to.equal(1);
        expect(raisedTokens[0]).to.equal(usdt.address);
      });

      it('should add a raised token correctly', async function () {
        await yexFTOFactory.addRaisedToken(mockToken.address);

        const raisedTokens = await yexFTOFactory.allRaisedTokens();
        expect(raisedTokens.length).to.equal(2);
        expect(raisedTokens[1]).to.equal(mockToken.address);

        const isAdded = await yexFTOFactory.isRaisedToken(mockToken.address);
        expect(isAdded).to.be.true;
      });

      it('should not add the same raised token twice', async function () {
          await yexFTOFactory.connect(factoryOwner).addRaisedToken(usdt.address);

          const raisedTokens = await yexFTOFactory.allRaisedTokens();
          expect(raisedTokens.length).to.equal(2);

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
          yexFTOFactory.connect(tokenLauncher).addRaisedToken(mockToken.address)
        ).to.be.revertedWith('Ownable: caller is not the owner');
      });

      it('should only allow the ftoFactory owner to remove a raised token', async function () {
        await expect(
          yexFTOFactory.connect(tokenLauncher).removeRaisedToken(usdt.address)
        ).to.be.revertedWith('Ownable: caller is not the owner');
      });
  });
});
