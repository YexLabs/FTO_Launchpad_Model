import { ethers, network } from "hardhat";
import { ERC20Faucet } from "./../../typechain-types/contracts/core/ERC20Faucet";
import { Incentive } from "./../../typechain-types/contracts/core/HPOT/Incentive";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import {
  HenloDexFactory,
  HenloDexRouterV2,
  YexFTOFacadeV2,
  YexFTOFactoryV2,
  YexFTOPairV2,
} from "../../typechain-types";

describe("Incentive", function () {
  let ftoFactory: YexFTOFactoryV2;
  let ftoFacade: YexFTOFacadeV2;
  let hpot: ERC20Faucet;
  let usdt: ERC20Faucet;
  let henloDexFactory: HenloDexFactory;
  let henloDexRouter: HenloDexRouterV2;
  let owner: SignerWithAddress,
    addr1: SignerWithAddress,
    addr2: SignerWithAddress,
    addr3: SignerWithAddress;
  let incentive: Incentive;
  let reward: BigNumber;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // USDT
    const ERC20Faucet = await ethers.getContractFactory("ERC20Faucet");
    usdt = (await ERC20Faucet.deploy("usdt", "usdt")) as ERC20Faucet;
    await usdt.deployed();

    // HPOT
    hpot = (await ERC20Faucet.deploy("hpot", "hpot")) as ERC20Faucet;
    await hpot.deployed();
    await hpot.faucet();

    // YexFTOFactoryV2
    const YexFTOFactoryV2 = await ethers.getContractFactory("YexFTOFactoryV2");
    ftoFactory = (await YexFTOFactoryV2.deploy()) as YexFTOFactoryV2;

    // YexFTOFacadeV2
    const YexFTOFacadeV2 = await ethers.getContractFactory("YexFTOFacadeV2");
    ftoFacade = (await YexFTOFacadeV2.deploy(
      ftoFactory.address
    )) as YexFTOFacadeV2;

    // add raisedToken and whitelist to FTOFactory
    await ftoFactory.addRaisedToken(usdt.address);
    await ftoFactory.batchAddWhiteList([
      owner.address,
      addr1.address,
      addr2.address,
    ]);

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

    const Incentive = await ethers.getContractFactory("Incentive");
    incentive = (await Incentive.deploy(
      ftoFactory.address,
      hpot.address,
      owner.address
    )) as Incentive;
    // reward
    reward = ethers.utils.parseUnits("1", 18);
    // setup rewardethers.utils.parseUnits("1", 18)
    await incentive.setRewardAmount(reward);
    // vault approve
    await hpot.approve(incentive.address, hpot.balanceOf(owner.address));

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
    console.log("HPOT address: ", hpot.address);
    console.log("INCENTIVE address: ", incentive.address);
  });

  it("test launchedToken FTO", async function () {
    const name = "TestToken";
    const symbol = "TT";

    const amount = ethers.utils.parseUnits("1000000000", 18);
    const poolHandler = henloDexRouter.address;
    const raisingCycle = 120; // 120 seconds

    // 1. create FTO
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

    // 2. deposit
    await usdt.connect(addr1).faucet();
    await usdt
      .connect(addr1)
      .approve(
        ftoFacade.address,
        await usdt.connect(addr1).balanceOf(addr1.address)
      );

    const deposit_amount = ethers.utils.parseUnits("100", 18);
    await usdt.connect(addr2).faucet();
    await usdt.connect(addr2).approve(ftoFacade.address, deposit_amount);
    await ftoFacade
      .connect(addr2)
      .deposit(usdt.address, launchedToken, deposit_amount);

    // 3. perform failed
    await expect(
      incentive.connect(addr2).perform(usdt.address, launchedToken)
    ).to.be.revertedWith("FTO pair have not finished.");
    expect(
      await incentive.connect(addr2).performable(usdt.address, launchedToken)
    ).to.be.equal(false);

    // Move time forward and mine a new block
    await network.provider.send("evm_increaseTime", [raisingCycle + 5]);
    await network.provider.send("evm_mine");

    // have no admin role
    await expect(incentive.connect(addr2).setVault(addr2.address)).to.be
      .reverted;
    await expect(incentive.connect(addr2).setRewardAmount(10)).to.be.reverted;

    // perform success
    expect(
      await incentive.connect(addr2).performable(usdt.address, launchedToken)
    ).to.be.equal(true);

    await incentive.connect(addr2).perform(usdt.address, launchedToken);
    expect(await hpot.balanceOf(addr2.address)).to.be.equal(reward);

    // perform duplicate
    await expect(incentive.connect(addr3).perform(usdt.address, launchedToken))
      .to.be.reverted;
  });
});
