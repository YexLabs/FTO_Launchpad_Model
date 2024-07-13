import { ethers, network } from "hardhat";
import { ERC20Faucet } from "./../../typechain-types/contracts/core/ERC20Faucet";
import { YexFTOFacadeV2 } from "./../../typechain-types/contracts/core/YexFTOFacadeV2";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import {
  HenloDexFactory,
  HenloDexPair,
  HenloDexRouterV2,
  YexFTOFactoryV2,
  YexFTOPairV2,
} from "../../typechain-types";

describe("YexFTO", function () {
  let ftoFactory: YexFTOFactoryV2;
  let ftoFacade: YexFTOFacadeV2;
  let henloDexFactory: HenloDexFactory;
  let henloDexRouter: HenloDexRouterV2;
  let usdt: ERC20Faucet;
  let owner: SignerWithAddress,
    addr1: SignerWithAddress,
    addr2: SignerWithAddress,
    addr3: SignerWithAddress;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // USDT
    const ERC20Faucet = await ethers.getContractFactory("ERC20Faucet");
    usdt = (await ERC20Faucet.deploy("usdt", "usdt")) as ERC20Faucet;
    await usdt.deployed();

    // YexFTOFactoryV2
    const YexFTOFactoryV2 = await ethers.getContractFactory("YexFTOFactoryV2");
    ftoFactory = (await YexFTOFactoryV2.deploy()) as YexFTOFactoryV2;

    // add raisedToken and whitelist to FTOFactory
    await ftoFactory.addRaisedToken(usdt.address);
    await ftoFactory.batchAddWhiteList([
      owner.address,
      addr1.address,
      addr2.address,
    ]);

    // YexFTOFacadeV2
    const YexFTOFacadeV2 = await ethers.getContractFactory("YexFTOFacadeV2");
    ftoFacade = (await YexFTOFacadeV2.deploy(
      ftoFactory.address
    )) as YexFTOFacadeV2;

    // HenloDexFactory
    const HenloDexFactory = await ethers.getContractFactory("HenloDexFactory");
    henloDexFactory = (await HenloDexFactory.deploy(
      owner.address
    )) as HenloDexFactory;
    await henloDexFactory.deployed();

    // HenloDexRouterV2
    const HenloDexRouterV2 = await ethers.getContractFactory(
      "HenloDexRouterV2"
    );
    henloDexRouter = (await HenloDexRouterV2.deploy(
      henloDexFactory.address,
      usdt.address
    )) as HenloDexRouterV2;
    await henloDexRouter.deployed();

    console.log("YexFTOFactoryV2 address: ", ftoFactory.address);
    console.log(
      "YexFTOFactoryV2 init code: ",
      await ftoFactory.INIT_CODE_PAIR_HASH()
    );
    console.log("YexFTOFacadeV2 address: ", ftoFacade.address);
    console.log("henloDexFactory address: ", henloDexFactory.address);
    console.log(
      "henloDexFactory initcode:",
      await henloDexFactory.INIT_CODE_PAIR_HASH()
    );
    console.log("henloDexRouter address: ", henloDexRouter.address);
    console.log("USDT address: ", usdt.address);
  });

  it("test 100% launchedToken FTO", async function () {
    const raisedTokens = await ftoFactory.allRaisedTokens();
    expect(raisedTokens.length).to.equal(1);
    expect(raisedTokens[0]).to.equal(usdt.address);

    // 1. test create FTO with an error token
    const ERC20Faucet = await ethers.getContractFactory("ERC20Faucet");
    const errRaisedToken = (await ERC20Faucet.deploy(
      "errRaisedToken",
      "errRaisedToken"
    )) as ERC20Faucet;
    await errRaisedToken.deployed();

    const name = "TestToken";
    const symbol = "TT";

    const amount = ethers.utils.parseUnits("1000000000", 18);
    const poolHandler = henloDexRouter.address;
    const raisingCycle = 120; // 120 seconds

    await expect(
      ftoFactory.createFTO(
        errRaisedToken.address,
        name,
        symbol,
        amount,
        100,
        poolHandler,
        raisingCycle,
        "0x"
      )
    ).to.revertedWith("YexFTOFactory: NOT_ALLOWED_BASE_TOKEN");

    // 2. test create FTO with an wallet which not in whitelist
    await expect(
      ftoFactory.connect(addr3).createFTO(
        usdt.address, // use usdt
        name,
        symbol,
        amount,
        100,
        poolHandler,
        raisingCycle,
        "0x"
      )
    ).to.revertedWith("WhiteList: only whiteList can create");

    // 3. create FTO
    await ftoFactory
      .connect(addr1)
      .createFTO(
        usdt.address,
        name,
        symbol,
        amount,
        100,
        poolHandler,
        raisingCycle,
        "0x"
      );

    const ftoPair_addr = await ftoFactory.allPairs(0);
    const YexFTOPairV2 = await ethers.getContractFactory("YexFTOPairV2");
    const ftoPair = YexFTOPairV2.attach(ftoPair_addr) as YexFTOPairV2;
    const launchedToken = await ftoPair.launchedToken();

    expect(await ftoFactory.allPairsLength()).to.equal(1);
    expect(await ftoPair.launchedTokenProvider()).to.equal(addr1.address);
    expect(
      await ftoFacade.getFTOPairProvider(usdt.address, launchedToken)
    ).to.equal(addr1.address);
    expect(
      await ftoFactory.getFTOPairProvider(usdt.address, launchedToken)
    ).to.equal(addr1.address);

    // 4. deposit usdt with provider
    expect(await ftoFacade.getFTOPair(usdt.address, launchedToken)).to.equal(
      ftoPair_addr
    );

    expect(await ftoFacade.getFTOState(usdt.address, launchedToken)).to.equal(
      3
    );

    await usdt.connect(addr1).faucet();
    await usdt
      .connect(addr1)
      .approve(
        ftoFacade.address,
        await usdt.connect(addr1).balanceOf(addr1.address)
      );

    await expect(
      ftoFacade
        .connect(addr1)
        .deposit(
          usdt.address,
          launchedToken,
          await usdt.balanceOf(addr1.address)
        )
    ).to.be.rejectedWith(
      "Project owner are not allowed to deposit with their launch"
    );

    // 5. deposit
    const deposit_amount = ethers.utils.parseUnits("100", 18);
    await usdt.connect(addr2).faucet();
    let usdt_balance_addr2 = await usdt.connect(addr2).balanceOf(addr2.address);
    await usdt.connect(addr2).approve(ftoFacade.address, deposit_amount);

    await ftoFacade
      .connect(addr2)
      .deposit(usdt.address, launchedToken, deposit_amount);

    expect(usdt_balance_addr2.sub(deposit_amount)).to.equal(
      await usdt.connect(addr2).balanceOf(addr2.address)
    );

    // refundRaisedToken when not paused will failed
    await expect(
      ftoFacade.connect(addr2).refundRaisedToken(usdt.address, launchedToken)
    ).to.be.rejectedWith("Project is in progress");

    // 6. deposit usdt when pause
    await ftoFactory.pause(usdt.address, launchedToken);
    expect(await ftoFacade.getFTOState(usdt.address, launchedToken)).to.equal(
      2
    );
    await usdt.connect(addr2).approve(ftoFacade.address, deposit_amount);
    await expect(
      ftoFacade
        .connect(addr2)
        .deposit(usdt.address, launchedToken, deposit_amount)
    ).to.be.rejectedWith("Project is paused");

    // 7. refund when paused

    // can't pause when project is paused.
    await expect(
      ftoFactory.pause(usdt.address, launchedToken)
    ).to.be.rejectedWith("Launchpad is not in progress");

    usdt_balance_addr2 = await usdt.connect(addr2).balanceOf(addr2.address);
    await ftoFacade
      .connect(addr2)
      .refundRaisedToken(usdt.address, launchedToken);
    expect(usdt_balance_addr2.add(deposit_amount)).to.equal(
      await usdt.connect(addr2).balanceOf(addr2.address)
    );

    // 8. deposit when unpaused
    await ftoFactory.resume(usdt.address, launchedToken);
    expect(await ftoFacade.getFTOState(usdt.address, launchedToken)).to.equal(
      3
    );

    usdt_balance_addr2 = await usdt.connect(addr2).balanceOf(addr2.address);
    await usdt.connect(addr2).approve(ftoFacade.address, deposit_amount);
    await ftoFacade
      .connect(addr2)
      .deposit(usdt.address, launchedToken, deposit_amount);
    expect(usdt_balance_addr2.sub(deposit_amount)).to.equal(
      await usdt.connect(addr2).balanceOf(addr2.address)
    );
    // 9. perform

    await expect(ftoPair.performUpkeep("0x")).to.be.rejectedWith(
      "fund raising not finished or paused"
    );
    await expect(
      ftoFacade.connect(addr2).claimLP(usdt.address, launchedToken)
    ).to.be.rejectedWith("fund rasing not success.");

    // Move time forward and mine a new block
    await network.provider.send("evm_increaseTime", [raisingCycle + 5]);
    await network.provider.send("evm_mine");

    expect((await ftoPair.checkUpkeep("0x"))[0]).to.be.true;

    await ftoPair.performUpkeep("0x");
    const poolPair_addr = await ftoPair.lpToken();

    const HenloDexPair = await ethers.getContractFactory("HenloDexPair");
    const poolPair = HenloDexPair.attach(poolPair_addr) as HenloDexPair;
    const total_supply = await poolPair.totalSupply();

    let total_Lp = await poolPair.balanceOf(ftoPair.address);

    let zero_lp = await poolPair.balanceOf(
      "0x0000000000000000000000000000000000000000"
    );

    const lp_provider = await ftoPair.claimableLP(addr1.address);
    const lp_provider_from_facade = await ftoFacade
      .connect(addr1)
      .claimableLP(usdt.address, launchedToken);
    const lp_depositer = await ftoPair.claimableLP(addr2.address);
    expect(lp_provider).to.equal(total_Lp.div(2));
    expect(lp_provider).to.equal(lp_provider_from_facade);
    expect(lp_depositer).to.equal(total_Lp.div(2));

    // 10. claimLP
    let balance_lp_depositer = await poolPair.balanceOf(addr2.address);
    let balance_lp_provider = await poolPair.balanceOf(addr1.address);

    expect(balance_lp_depositer).to.equal(0);
    expect(balance_lp_provider).to.equal(0);

    await ftoFacade.connect(addr2).claimLP(usdt.address, launchedToken);
    await ftoPair.connect(addr1).claimLP(addr1.address); // provider need direct call pair claimLP function.

    expect(await poolPair.balanceOf(addr2.address)).to.equal(lp_depositer);
    expect(await poolPair.balanceOf(addr1.address)).to.equal(lp_provider);

    let after_claim_total_Lp = await poolPair.balanceOf(ftoFactory.address);
    expect(after_claim_total_Lp.add(total_Lp).add(zero_lp)).to.equal(
      total_supply
    );

    // 11. owner withdrawLP
    let owner_lp_balance = await poolPair.balanceOf(owner.address);
    expect(owner_lp_balance).to.equal(0);
    await ftoFactory.withdrawFee(usdt.address, launchedToken, owner.address);
    expect(await poolPair.balanceOf(owner.address)).to.equal(
      after_claim_total_Lp
    );
  });
  it("test 95% launched FTO", async function () {
    const name = "TestToken";
    const symbol = "TT";

    const amount = ethers.utils.parseUnits("1000000000", 18);
    const poolHandler = henloDexRouter.address;
    const raisingCycle = 120; // 120 seconds
    const launchedPercent = 95;

    // 1. create FTO
    await ftoFactory.connect(addr1).createFTO(
      usdt.address,
      name,
      symbol,
      amount,
      launchedPercent, // not 100% launched
      poolHandler,
      raisingCycle,
      "0x"
    );

    const ftoPair_addr = await ftoFactory.allPairs(0);
    const YexFTOPairV2 = await ethers.getContractFactory("YexFTOPairV2");
    const ftoPair = YexFTOPairV2.attach(ftoPair_addr) as YexFTOPairV2;
    const launchedToken = await ftoPair.launchedToken();

    // 2. deposit
    let deposit_amount = ethers.utils.parseUnits("100", 18);
    await usdt.connect(addr2).faucet();
    await usdt.connect(addr2).approve(ftoFacade.address, deposit_amount);
    await ftoFacade
      .connect(addr2)
      .deposit(usdt.address, launchedToken, deposit_amount);

    deposit_amount = ethers.utils.parseUnits("200", 18);
    await usdt.connect(addr3).faucet();
    await usdt.connect(addr3).approve(ftoFacade.address, deposit_amount);
    await ftoFacade
      .connect(addr3)
      .deposit(usdt.address, launchedToken, deposit_amount);

    // 3. perform
    // Move time forward and mine a new block
    await network.provider.send("evm_increaseTime", [raisingCycle + 5]);
    await network.provider.send("evm_mine");

    expect((await ftoPair.checkUpkeep("0x"))[0]).to.be.true;

    await ftoPair.performUpkeep("0x");

    const ERC20 = await ethers.getContractFactory("ERC20Faucet");
    const launchedTokenContract = ERC20.attach(launchedToken) as ERC20Faucet;
    // console.log(await launchedTokenContract.balanceOf(ftoPair.address));
    expect(await launchedTokenContract.balanceOf(ftoPair.address)).to.equal(
      amount.mul(100 - launchedPercent).div(100)
    );

    // 4. claimable launched Token
    const launchedToken_amount_addr2 = await ftoPair.claimableLaunchedToken(
      addr2.address
    );
    const launchedToken_amount_addr3 = await ftoPair.claimableLaunchedToken(
      addr3.address
    );

    const launchedToken_amount_addr2_by_factory = await ftoFacade
      .connect(addr2)
      .claimableLaunchedToken(usdt.address, launchedToken);
    const launchedToken_amount_addr3_by_factory = await ftoFacade
      .connect(addr3)
      .claimableLaunchedToken(usdt.address, launchedToken);

    expect(launchedToken_amount_addr2).to.be.equal(
      launchedToken_amount_addr2_by_factory
    );
    expect(launchedToken_amount_addr3).to.be.equal(
      launchedToken_amount_addr3_by_factory
    );

    // 5. claim
    await expect(ftoPair.claimLaunchedToken(owner.address)).to.be.revertedWith(
      "only raised token depositer can claim."
    );
    await expect(ftoPair.claimLaunchedToken(addr1.address)).to.be.revertedWith(
      "only raised token depositer can claim."
    );

    await ftoPair.claimLaunchedToken(addr2.address);
    await ftoPair.claimLaunchedToken(addr3.address);

    expect(launchedToken_amount_addr2).to.equal(
      await launchedTokenContract.balanceOf(addr2.address)
    );
    expect(launchedToken_amount_addr3).to.equal(
      await launchedTokenContract.balanceOf(addr3.address)
    );

    await expect(ftoPair.claimLaunchedToken(addr3.address)).to.be.revertedWith(
      "claimer has claimed."
    );
  });
});
