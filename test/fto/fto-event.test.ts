import { expect } from 'chai';
import { deployContracts } from '../common/deployment';
import { createFTO, generateSignersAndAmounts } from './../common/helpers';
describe('FTO Events test', function () {
  let tokenLauncher: SignerWithAddress, factoryOwner: SignerWithAddress;
  let usdt: Contract;
  let yexFTOFactory: Contract;
  let yexFTOFacade: Contract;
  let henloDexRouter: Contract;

  let yexFTOPairs: Contract[] = [];
  let launchedTokens = [];

  let depositors: SignerWithAddress[];
  let amounts: ethers.BigNumber[];

  before('Deploy Contracts and create FTOs', async () => {
    [factoryOwner, tokenLauncher] = await ethers.getSigners();

    ({ usdt, yexFTOFactory, yexFTOFacade, henloDexRouter } =
      await deployContracts());

    for (let i = 0; i < 5; i++) {
      await createFTO(yexFTOFactory, tokenLauncher, {
        raisedToken: usdt.address,
        dexRouter: henloDexRouter.address,
      });

      const ftoPairsLength = await yexFTOFactory.allPairsLength();
      const createdPair = await yexFTOFactory.allPairs(ftoPairsLength - 1);
      const yexFTOPair = await ethers.getContractAt(
        'YexFTOPairV2',
        createdPair,
      );

      yexFTOPairs.push(yexFTOPair);

      launchedTokens.push(await yexFTOPair.launchedToken());
    }

    [depositors, amounts] = await generateSignersAndAmounts(
      [300, 400],
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

  it('should deposit fto0,fto2,fto4 by depositor0', async () => {
    /**
     * depositor: depositors[0]
     * amount: amounts[0]
     */
    // yexFTOPairs[0]
    await usdt.connect(depositors[0]).approve(yexFTOFacade.address, amounts[0]);
    await yexFTOFacade
      .connect(depositors[0])
      .deposit(usdt.address, launchedTokens[0], amounts[0]);

    // yexFTOPairs[2]
    await usdt.connect(depositors[0]).approve(yexFTOFacade.address, amounts[0]);
    await yexFTOFacade
      .connect(depositors[0])
      .deposit(usdt.address, launchedTokens[2], amounts[0]);

    // yexFTOPairs[4]
    await usdt.connect(depositors[0]).approve(yexFTOFacade.address, amounts[0]);
    await yexFTOFacade
      .connect(depositors[0])
      .deposit(usdt.address, launchedTokens[4], amounts[0]);

    let events = await yexFTOFactory.events(depositors[0].address);

    expect(events).to.include(yexFTOPairs[0].address);
    expect(events).to.include(yexFTOPairs[2].address);
    expect(events).to.include(yexFTOPairs[4].address);

    expect(events.length).to.equal(3);

    expect(events[0]).to.equal(yexFTOPairs[0].address);
    expect(events[1]).to.equal(yexFTOPairs[2].address);
  });

  it('should deposit fto1,fto1, fto3 by depositor1', async () => {
    /**
     * depositor: depositors[1]
     * amount: amounts[1]
     */
    // yexFTOPairs[1]
    await usdt.connect(depositors[1]).approve(yexFTOFacade.address, amounts[1]);
    await yexFTOFacade
      .connect(depositors[1])
      .deposit(usdt.address, launchedTokens[1], amounts[1]);

    // yexFTOPairs[1]
    await usdt.connect(depositors[1]).approve(yexFTOFacade.address, amounts[1]);
    await yexFTOFacade
      .connect(depositors[1])
      .deposit(usdt.address, launchedTokens[1], amounts[1]);

    // yexFTOPairs[3]
    await usdt.connect(depositors[1]).approve(yexFTOFacade.address, amounts[1]);
    await yexFTOFacade
      .connect(depositors[1])
      .deposit(usdt.address, launchedTokens[3], amounts[1]);

    let events = await yexFTOFactory.events(depositors[1].address);

    expect(events.length).to.equal(2);
    expect(events[0]).to.equal(yexFTOPairs[1].address);
    expect(events[1]).to.equal(yexFTOPairs[3].address);
  });

  it('should revert direct call of removeEvent', async () => {
    await expect(
      yexFTOFactory.removeEvent(depositors[1].address, yexFTOPairs[1].address),
    ).to.revertedWithCustomError(yexFTOFactory, 'RaisedTokenStillRemaining');
  });

  it('should refund Raised Token for depositor0', async () => {
    //depositor0:  ftopair0,2,4
    await yexFTOFactory
      .connect(factoryOwner)
      .pause(usdt.address, launchedTokens[2]);

    await yexFTOPairs[2].connect(depositors[0]).refundRaisedToken();

    let events = await yexFTOFactory.events(depositors[0].address);

    expect(events.length).to.equal(2);
    expect(events[0]).to.equal(yexFTOPairs[0].address);
    expect(events[1]).to.equal(yexFTOPairs[4].address);

    await expect(
      yexFTOPairs[2].connect(depositors[0]).refundRaisedToken(),
    ).to.revertedWithCustomError(yexFTOPairs[2], 'InvalidAmount');

    await expect(
      yexFTOFactory.removeEvent(depositors[0].address, yexFTOPairs[2].address),
    ).to.revertedWithCustomError(yexFTOFactory, 'NotParticipateInThisFTOPair');

    await expect(
      yexFTOFactory.removeEvent(depositors[0].address, yexFTOPairs[0].address),
    ).to.revertedWithCustomError(yexFTOFactory, 'RaisedTokenStillRemaining');
  });

  it('should refund Raised Token for depositor1', async () => {
    //depositor1:  ftopair1,3
    await yexFTOFactory
      .connect(factoryOwner)
      .pause(usdt.address, launchedTokens[1]);

    await yexFTOPairs[1].connect(depositors[1]).refundRaisedToken();

    await yexFTOFactory
      .connect(factoryOwner)
      .pause(usdt.address, launchedTokens[3]);

    await yexFTOPairs[3].connect(depositors[1]).refundRaisedToken();

    let events = await yexFTOFactory.events(depositors[1].address);
    expect(events.length).to.equal(0);
  });
});
