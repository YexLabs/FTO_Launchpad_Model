import { expect } from 'chai';
import { deployContracts } from '../common/deployment';
import { createFTO, generateSignersAndAmounts } from './../common/helpers';
import { Status, FTOParams } from '../common/constants';

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

    it("should have depositedLaunchedToken equal to launched token's initial supply", async () => {
      expect(await yexFTOPair.depositedLaunchedToken()).to.equal(
        FTOParams.AMOUNT,
      );
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

  describe('FTO Pair: Refund raised token', function () {
    it('should not refund when ftopair is not paused', async () => {
      await expect(
        yexFTOPair.connect(depositors[0]).refundRaisedToken(),
      ).to.revertedWithCustomError(yexFTOPair, 'FTOPairStatusError');
    });

    it('should refund raised token', async () => {
      await yexFTOFactory
        .connect(factoryOwner)
        .pause(usdt.address, launchedToken);

      const prevDepositedRaisedToken = await yexFTOPair.depositedRaisedToken();

      await yexFTOPair.connect(depositors[0]).refundRaisedToken();

      const afterDepositedRaisedToken = await yexFTOPair.depositedRaisedToken();

      await yexFTOFactory
        .connect(factoryOwner)
        .resume(usdt.address, launchedToken);

      expect(afterDepositedRaisedToken).to.equal(
        prevDepositedRaisedToken.sub(amounts[0]),
      );
    });
  });

  describe('FTO Pair: Perform', function () {
    it('should return false in checkUpKeep', async () => {
      const [upkeepNeeded] = await yexFTOPair.checkUpkeep('0x');

      expect(upkeepNeeded).to.be.false;
    });

    it('should return true in checkUpKeep after raising cycle', async () => {
      await network.provider.send('evm_increaseTime', [
        FTOParams.RAISING_CYCLE + 5,
      ]);
      await network.provider.send('evm_mine');

      const [upkeepNeeded] = await yexFTOPair.checkUpkeep('0x');
      expect(upkeepNeeded).to.be.true;
    });

    it('should execute perform', async () => {
      await expect(yexFTOPair.performUpkeep('0x'))
        .to.emit(yexFTOPair, 'Perform')
        .withArgs(Status.Success);
    });

    if (
      ('should deploy LP token correctly after performUpkeep',
      async () => {
        const lpTokenAddress = await yexFTOPair.lpToken();
        expect(lpTokenAddress).to.be.properAddress;

        const henloDexPair = await ethers.getContractAt(
          'HenloDexPair',
          lpTokenAddress,
        );

        const token0 = await henloDexPair.token0();
        const token1 = await henloDexPair.token1();

        expect(token0).to.be.oneOf([usdt.address, launchedToken]);
        expect(token1).to.be.oneOf([usdt.address, launchedToken]);
      })
    );
  });
});
