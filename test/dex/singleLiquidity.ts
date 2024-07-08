import { ethers } from "hardhat";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import {
  ERC20Faucet,
  HenloDexFactory,
  HenloDexPair,
  HenloDexRouterV2,
} from "../../typechain-types";

describe("HenloDex Single Liquidity", function () {
  let henloDexFactory: HenloDexFactory;
  let henloDexRouter: HenloDexRouterV2;
  let usdt: ERC20Faucet;
  let bera: ERC20Faucet;
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

    // bera
    bera = (await ERC20Faucet.deploy("bera", "bera")) as ERC20Faucet;
    await bera.deployed();

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

    console.log("henloDexFactory address: ", henloDexFactory.address);
    console.log(
      "henloDexFactory initcode:",
      await henloDexFactory.INIT_CODE_PAIR_HASH()
    );
    console.log("henloDexRouter address: ", henloDexRouter.address);
    console.log("USDT address: ", usdt.address);
    console.log("bera address: ", bera.address);
  });

  it("test single-side liquidity", async function () {
    // 1. owner init LP
    await usdt.faucet();
    await bera.faucet();

    const amount = ethers.utils.parseUnits("100", 18);

    let deadline =
      (await ethers.provider.getBlock(ethers.provider.blockNumber)).timestamp +
      100;

    await usdt.approve(henloDexRouter.address, amount);
    await bera.approve(henloDexRouter.address, amount);

    await henloDexRouter.addLiquidity(
      usdt.address,
      bera.address,
      amount,
      amount,
      0,
      0,
      owner.address,
      deadline
    );

    const pairAddress = await henloDexFactory.getPair(
      usdt.address,
      bera.address
    );
    const HenloDexPair = await ethers.getContractFactory("HenloDexPair");
    const pair = HenloDexPair.attach(pairAddress) as HenloDexPair;

    console.log("owner lp", await pair.balanceOf(owner.address));

    expect(await pair.name()).to.equal("usdt_bera HLP");
    expect(await pair.symbol()).to.equal("usdt_bera HLP");
    expect((await pair.getReserves())._reserve0).to.equal(
      BigNumber.from("100000000000000000000")
    );
    expect((await pair.getReserves())._reserve1).to.equal(
      BigNumber.from("100000000000000000000")
    );

    expect(await pair.balanceOf(owner.address)).to.equal(99999999999999999000n);

    // 2. address1 add normal liquidity
    await usdt.connect(addr1).faucet();
    await bera.connect(addr1).faucet();

    const amount_addr1 = ethers.utils.parseUnits("200", 18);

    deadline =
      (await ethers.provider.getBlock(ethers.provider.blockNumber)).timestamp +
      100;

    await usdt.connect(addr1).approve(henloDexRouter.address, amount_addr1);
    await bera.connect(addr1).approve(henloDexRouter.address, amount_addr1);

    await henloDexRouter
      .connect(addr1)
      .addLiquidity(
        usdt.address,
        bera.address,
        amount_addr1,
        amount_addr1,
        0,
        0,
        addr1.address,
        deadline
      );

    console.log("addr1 lp", await pair.balanceOf(addr1.address));

    expect((await pair.getReserves())._reserve0).to.equal(
      BigNumber.from("300000000000000000000")
    );
    expect((await pair.getReserves())._reserve1).to.equal(
      BigNumber.from("300000000000000000000")
    );
    expect(await pair.balanceOf(addr1.address)).to.equal(
      199999999999999999997n
    );

    // 3. address2 add single-side liquidity
    await usdt.connect(addr2).faucet();
    await bera.connect(addr2).faucet();

    const amount_addr2 = ethers.utils.parseUnits("150", 18);

    deadline =
      (await ethers.provider.getBlock(ethers.provider.blockNumber)).timestamp +
      100;

    await usdt.connect(addr2).approve(henloDexRouter.address, amount_addr2);

    await henloDexRouter.connect(addr2).addLiquidity(
      usdt.address,
      bera.address,
      amount_addr2,
      0, // zero bera
      0,
      0,
      addr2.address,
      deadline
    );

    expect((await pair.getReserves())._reserve0).to.equal(
      BigNumber.from("450000000000000000000")
    );
    expect((await pair.getReserves())._reserve1).to.equal(
      BigNumber.from("300000000000000000000")
    );
    expect(await pair.balanceOf(addr2.address)).to.equal(67423461417476714728n);
  });
});
