import { expect } from 'chai';
import { deployContracts } from '../common/deployment';
import { createFTO, generateSignersAndAmounts } from './../common/helpers';
import { Status } from '../common/constants';

describe('FTO Pair test', function () {
  let usdt: Contract;
  let yexFTOFactory: Contract;
  let yexFTOFacade: Contract;
  let henloDexFactory: Contract;
  let henloDexRouter: Contract;
  let yexFTOPair: Contract;

  let tokenLauncher: SignerWithAddress, factoryOwner: SignerWithAddress;
  let launchedToken;

  let depositors: SignerWithAddress[];
  let amounts: ethers.BigNumber[];

  before('Deploy Contracts and create FTO', async () => {
    [factoryOwner, tokenLauncher] = await ethers.getSigners();

    ({ usdt, yexFTOFactory, yexFTOFacade, henloDexFactory, henloDexRouter } =
      await deployContracts());

    await yexFTOFactory.addWhiteList(tokenLauncher.address);
    await createFTO(yexFTOFactory, tokenLauncher, {
      raisedToken: usdt.address,
      dexRouter: henloDexRouter.address,
    });

    const ftoPairsLength = await yexFTOFactory.allPairsLength();
    const createdPair = await yexFTOFactory.allPairs(ftoPairsLength - 1);
    yexFTOPair = await ethers.getContractAt('YexFTOPairV2', createdPair);
    launchedToken = await yexFTOPair.launchedToken();

    await usdt.connect(tokenLauncher).faucet();

    [depositors, amounts] = await generateSignersAndAmounts(
      [300, 400, 300],
      await usdt.decimals(),
    );

    await Promise.all(
      depositors.map(async (depositor, index) => {
        await usdt.connect(depositor).faucet();
        await usdt
          .connect(depositor)
          .approve(yexFTOFacade.address, amounts[index]);
      }),
    );
  });

  describe('FTO Pair: Get FTO Pair Info', function () {
    it('should get FTO token launcher via factory', async () => {
      expect(
        await yexFTOFactory.getFTOPairProvider(usdt.address, launchedToken),
      ).to.equal(tokenLauncher.address);
    });

    it('should get FTO token launcher via facade', async () => {
      expect(
        await yexFTOFacade.getFTOPairProvider(usdt.address, launchedToken),
      ).to.equal(tokenLauncher.address);
    });

    it('should get FTO Pair address via facade', async () => {
      expect(
        await yexFTOFacade.getFTOPair(usdt.address, launchedToken),
      ).to.equal(yexFTOPair.address);
    });

    it('should get FTO Pair state via facade', async () => {
      expect(
        await yexFTOFacade.getFTOState(usdt.address, launchedToken),
      ).to.equal(Status.Processing);
    });
  });

  describe('FTO Pair: Deposit raised token', function () {
    it('should not deposit when ftopair is paused', async () => {
      await yexFTOFactory
        .connect(factoryOwner)
        .pause(usdt.address, launchedToken);
      await expect(
        yexFTOFacade
          .connect(depositors[0])
          .deposit(usdt.address, launchedToken, amounts[0]),
      ).to.revertedWithCustomError(yexFTOPair, 'FTOPairStatusError');

      await yexFTOFactory
        .connect(factoryOwner)
        .resume(usdt.address, launchedToken);
    });

    it('should not deposit when depositor is token launcher', async () => {
      await usdt
        .connect(tokenLauncher)
        .approve(yexFTOFacade.address, amounts[0]);
      await expect(
        yexFTOFacade
          .connect(tokenLauncher)
          .deposit(usdt.address, launchedToken, amounts[0]),
      ).to.revertedWithCustomError(yexFTOPair, 'ProjectOwnerDepositNotAllowed');
    });

    it('should not call depositRaisedToken directly', async () => {
      await expect(
        yexFTOPair
          .connect(depositors[0])
          .depositRaisedToken(depositors[0].address, amounts[0]),
      ).to.revertedWithCustomError(yexFTOPair, 'NotDepositedRaisedToken');
    });

    it('should deposit raised token', async () => {
      for (let i = 0; i < depositors.length; i++) {
        const prevDepositedRaisedToken =
          await yexFTOPair.depositedRaisedToken();
        await yexFTOFacade
          .connect(depositors[i])
          .deposit(usdt.address, launchedToken, amounts[i]);
        const afterDepositedRaisedToken =
          await yexFTOPair.depositedRaisedToken();
        expect(afterDepositedRaisedToken).to.equal(
          prevDepositedRaisedToken.add(amounts[i]),
        );
      }
    });
  });
});
