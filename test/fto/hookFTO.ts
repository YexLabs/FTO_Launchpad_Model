import { ethers, network } from "hardhat";
import { ERC20Faucet } from "../../typechain-types/contracts/core/ERC20Faucet";
import { YexFTOFacadeV2 } from "../../typechain-types/contracts/core/YexFTOFacadeV2";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import {
  CreateHooks,
  CustomHook,
  HenloDexFactory,
  HenloDexPair,
  HenloDexRouterV2,
  YexFTOFactoryV2,
  YexFTOPairV2,
} from "../../typechain-types";

describe("YexFTO", function () {
  let customHook: CustomHook;
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

    // CustomHook
    const CreateHooks = await ethers.getContractFactory("CreateHooks");
    const createHooks = (await CreateHooks.deploy()) as CreateHooks;
    const findResult = await createHooks.findSalt(ftoFactory.address);

    const customHookAddr = findResult[0];

    await createHooks.createHook(findResult[1], ftoFactory.address);

    const CustomHook = await ethers.getContractFactory("CustomHook");
    customHook = CustomHook.attach(customHookAddr) as CustomHook;
    await ftoFactory.batchAddWhiteList([customHook.address]);

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

  it("test CustomHook launched FTO", async function () {
    const name = "TestToken";
    const symbol = "TT";

    const amount = ethers.utils.parseUnits("1000000000", 18);
    const poolHandler = henloDexRouter.address;
    const raisingCycle = 120; // 120 seconds
    const launchedPercent = 95;

    const hookPercent = 50; // lock 50% lp

    let startTimestamp =
      (await ethers.provider.getBlock(ethers.provider.blockNumber)).timestamp +
      raisingCycle +
      100; // after raised+100
    const durationSeconds = 10000; // vesting duaration

    const hook_params = ethers.utils.defaultAbiCoder.encode(
      ["uint64", "uint64", "address"],
      [startTimestamp, durationSeconds, owner.address]
    );

    const data = ethers.utils.defaultAbiCoder.encode(
      ["uint256", "bytes"],
      [hookPercent, hook_params]
    );

    // 1. customHook createFTO
    await customHook.createFTO(
      usdt.address,
      name,
      symbol,
      amount,
      launchedPercent,
      poolHandler,
      raisingCycle,
      data
    );

    const ftoPair_addr = await ftoFactory.allPairs(0);
    const YexFTOPairV2 = await ethers.getContractFactory("YexFTOPairV2");
    const ftoPair = YexFTOPairV2.attach(ftoPair_addr) as YexFTOPairV2;
    const launchedToken = await ftoPair.launchedToken();

    expect(await ftoPair.percent4hook()).to.be.equal(hookPercent);
    expect(await customHook.beneficiary(ftoPair_addr)).to.be.equal(
      ftoPair_addr
    );
    expect(await customHook.start(ftoPair_addr)).to.be.equal(startTimestamp);
    expect(await customHook.duration(ftoPair_addr)).to.be.equal(
      durationSeconds
    );

    // 2. deposit and perform
    const deposit_amount = ethers.utils.parseUnits("100", 18);
    await usdt.connect(addr2).faucet();
    await usdt.connect(addr2).approve(ftoFacade.address, deposit_amount);

    await ftoFacade
      .connect(addr2)
      .deposit(usdt.address, launchedToken, deposit_amount);

    await network.provider.send("evm_increaseTime", [raisingCycle + 5]);
    await network.provider.send("evm_mine");

    expect((await ftoPair.checkUpkeep("0x"))[0]).to.be.true;

    await ftoPair.performUpkeep("0x");

    // 3. Check
    const poolPair_addr = await ftoPair.lpToken();
    const HenloDexPair = await ethers.getContractFactory("HenloDexPair");
    const poolPair = HenloDexPair.attach(poolPair_addr) as HenloDexPair;

    const total_supply = await poolPair.totalSupply();
    let total_Lp_pool = await poolPair.balanceOf(ftoPair.address);
    let factory_Lp_fee = await poolPair.balanceOf(ftoFactory.address);
    let zero_lp = await poolPair.balanceOf(
      "0x0000000000000000000000000000000000000000"
    );
    let customHook_lp = await poolPair.balanceOf(customHook.address);
    expect(
      customHook_lp.add(zero_lp).add(factory_Lp_fee).add(total_Lp_pool)
    ).to.equal(total_supply);

    // 4. release rule
    const before_releasable = await customHook.releasable(ftoPair.address);
    expect(before_releasable).to.be.equal(0);

    await network.provider.send("evm_increaseTime", [durationSeconds / 2]);
    await network.provider.send("evm_mine");

    const after_releasable = await customHook.releasable(ftoPair.address);
    expect(after_releasable).to.be.greaterThan(before_releasable);

    await network.provider.send("evm_increaseTime", [durationSeconds + 100]);
    await network.provider.send("evm_mine");
    expect(await customHook.releasable(ftoPair.address)).to.be.equal(
      customHook_lp
    );
  });
  it("test CustomHook launched FTO vesting", async function () {
    const name = "TestToken";
    const symbol = "TT";

    const amount = ethers.utils.parseUnits("1000000000", 18);
    const poolHandler = henloDexRouter.address;
    const raisingCycle = 120; // 120 seconds
    const launchedPercent = 95;

    const hookPercent = 50; // lock 50% lp

    let startTimestamp =
      (await ethers.provider.getBlock(ethers.provider.blockNumber)).timestamp +
      raisingCycle; // after raised
    const durationSeconds = 10000; // vesting duaration

    const hook_params = ethers.utils.defaultAbiCoder.encode(
      ["uint64", "uint64", "address"],
      [startTimestamp, durationSeconds, owner.address]
    );

    const data = ethers.utils.defaultAbiCoder.encode(
      ["uint256", "bytes"],
      [hookPercent, hook_params]
    );

    // 1. customHook createFTO
    await customHook.createFTO(
      usdt.address,
      name,
      symbol,
      amount,
      launchedPercent,
      poolHandler,
      raisingCycle,
      data
    );

    const ftoPair_addr = await ftoFactory.allPairs(0);
    const YexFTOPairV2 = await ethers.getContractFactory("YexFTOPairV2");
    const ftoPair = YexFTOPairV2.attach(ftoPair_addr) as YexFTOPairV2;
    const launchedToken = await ftoPair.launchedToken();

    expect(await ftoPair.percent4hook()).to.be.equal(hookPercent);
    expect(await customHook.beneficiary(ftoPair_addr)).to.be.equal(
      ftoPair_addr
    );
    expect(await customHook.start(ftoPair_addr)).to.be.equal(startTimestamp);
    expect(await customHook.duration(ftoPair_addr)).to.be.equal(
      durationSeconds
    );

    // 2. deposit and perform
    const deposit_amount = ethers.utils.parseUnits("100", 18);
    await usdt.connect(addr2).faucet();
    await usdt.connect(addr2).approve(ftoFacade.address, deposit_amount);

    await ftoFacade
      .connect(addr2)
      .deposit(usdt.address, launchedToken, deposit_amount);

    await network.provider.send("evm_increaseTime", [raisingCycle + 5]);
    await network.provider.send("evm_mine");

    expect((await ftoPair.checkUpkeep("0x"))[0]).to.be.true;

    await ftoPair.performUpkeep("0x");

    // 3. Check
    const poolPair_addr = await ftoPair.lpToken();
    const HenloDexPair = await ethers.getContractFactory("HenloDexPair");
    const poolPair = HenloDexPair.attach(poolPair_addr) as HenloDexPair;

    // 4. depositer claim
    const before_balance = await poolPair.balanceOf(addr2.address);
    const claimable_amount = await ftoPair
      .connect(addr2)
      .claimableLP(addr2.address);
    await ftoPair.connect(addr2).claimLP(addr2.address);
    expect(await poolPair.balanceOf(addr2.address)).to.be.equal(
      claimable_amount.add(before_balance)
    );
    expect(await ftoPair.connect(addr2).claimableLP(addr2.address)).to.be.equal(
      0
    );

    // 5. increase release
    await network.provider.send("evm_increaseTime", [100]);
    await customHook.release(ftoPair.address);
    expect(
      await ftoPair.connect(addr2).claimableLP(addr2.address)
    ).to.be.greaterThan(0);
  });
  it("test CustomHook launched FTO burn", async function () {
    const name = "TestToken";
    const symbol = "TT";

    const amount = ethers.utils.parseUnits("1000000000", 18);
    const poolHandler = henloDexRouter.address;
    const raisingCycle = 120; // 120 seconds
    const launchedPercent = 95;

    const hookPercent = 50; // lock 50% lp

    let startTimestamp =
      (await ethers.provider.getBlock(ethers.provider.blockNumber)).timestamp +
      raisingCycle; // after raised
    const durationSeconds = 10000; // vesting duaration

    const hook_params = ethers.utils.defaultAbiCoder.encode(
      ["uint64", "uint64", "address"],
      [startTimestamp, durationSeconds, owner.address]
    );

    const data = ethers.utils.defaultAbiCoder.encode(
      ["uint256", "bytes"],
      [hookPercent, hook_params]
    );

    // 1. customHook createFTO
    await customHook.createFTO(
      usdt.address,
      name,
      symbol,
      amount,
      launchedPercent,
      poolHandler,
      raisingCycle,
      data
    );

    const ftoPair_addr = await ftoFactory.allPairs(0);
    const YexFTOPairV2 = await ethers.getContractFactory("YexFTOPairV2");
    const ftoPair = YexFTOPairV2.attach(ftoPair_addr) as YexFTOPairV2;
    const launchedToken = await ftoPair.launchedToken();

    expect(await ftoPair.percent4hook()).to.be.equal(hookPercent);
    expect(await customHook.beneficiary(ftoPair_addr)).to.be.equal(
      ftoPair_addr
    );
    expect(await customHook.start(ftoPair_addr)).to.be.equal(startTimestamp);
    expect(await customHook.duration(ftoPair_addr)).to.be.equal(
      durationSeconds
    );

    // 2. deposit and perform
    const deposit_amount = ethers.utils.parseUnits("100", 18);
    await usdt.connect(addr2).faucet();
    await usdt.connect(addr2).approve(ftoFacade.address, deposit_amount);

    await ftoFacade
      .connect(addr2)
      .deposit(usdt.address, launchedToken, deposit_amount);

    await network.provider.send("evm_increaseTime", [raisingCycle + 5]);
    await network.provider.send("evm_mine");

    expect((await ftoPair.checkUpkeep("0x"))[0]).to.be.true;

    await ftoPair.performUpkeep("0x");

    // 3. Check
    const poolPair_addr = await ftoPair.lpToken();
    const HenloDexPair = await ethers.getContractFactory("HenloDexPair");
    const poolPair = HenloDexPair.attach(poolPair_addr) as HenloDexPair;

    // 4. TODO: provider claim
    const claimable_amount = await ftoPair.claimableLP(customHook.address);
  });
});
