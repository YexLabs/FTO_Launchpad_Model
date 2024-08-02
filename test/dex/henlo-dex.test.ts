import { ethers } from 'hardhat';
import { expect } from 'chai';
import { deployContracts } from '../common/deployment';
import { BigNumber } from 'ethers';

describe('HenloDex Single Liquidity', function () {
  let usdt: Contract;
  let henloDexFactory: Contract;
  let henloDexRouter: Contract;
  let bera: Contract;

  let owner: SignerWithAddress,
    addr1: SignerWithAddress,
    addr2: SignerWithAddress;

  before('Deploy Contracts', async () => {
    [owner, addr1, addr2] = await ethers.getSigners();
    ({ usdt, bera, henloDexFactory, henloDexRouter } = await deployContracts());
  });

  it('test single-side liquidity', async function () {
    // 1. owner init LP
    await usdt.faucet();
    await bera.faucet();

    const amount = ethers.utils.parseUnits('100', 18);

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
      deadline,
    );

    const pairAddress = await henloDexFactory.getPair(
      usdt.address,
      bera.address,
    );
    const HenloDexPair = await ethers.getContractFactory('HenloDexPair');
    const pair = HenloDexPair.attach(pairAddress) as HenloDexPair;

    const expectedName =
      usdt.address < bera.address ? 'usdt_bera HLP' : 'bera_usdt HLP';
    const expectedSymbol = expectedName;

    expect(await pair.name()).to.equal(expectedName);
    expect(await pair.symbol()).to.equal(expectedSymbol);
    expect((await pair.getReserves())._reserve0).to.equal(
      BigNumber.from('100000000000000000000'),
    );
    expect((await pair.getReserves())._reserve1).to.equal(
      BigNumber.from('100000000000000000000'),
    );

    expect(await pair.balanceOf(owner.address)).to.equal(99999999999999999000n);

    // 2. address1 add normal liquidity
    await usdt.connect(addr1).faucet();
    await bera.connect(addr1).faucet();

    const amount_addr1 = ethers.utils.parseUnits('200', 18);

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
        deadline,
      );
    expect((await pair.getReserves())._reserve0).to.equal(
      BigNumber.from('300000000000000000000'),
    );
    expect((await pair.getReserves())._reserve1).to.equal(
      BigNumber.from('300000000000000000000'),
    );
    expect(await pair.balanceOf(addr1.address)).to.equal(
      199999999999999999997n,
    );

    // 3. address2 add single-side liquidity
    await usdt.connect(addr2).faucet();
    await bera.connect(addr2).faucet();

    const amount_addr2 = ethers.utils.parseUnits('150', 18);

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
      deadline,
    );

    if (usdt.address < bera.address) {
      expect((await pair.getReserves())._reserve0).to.equal(
        BigNumber.from('450000000000000000000'),
      );
      expect((await pair.getReserves())._reserve1).to.equal(
        BigNumber.from('300000000000000000000'),
      );
    } else {
      expect((await pair.getReserves())._reserve0).to.equal(
        BigNumber.from('300000000000000000000'),
      );
      expect((await pair.getReserves())._reserve1).to.equal(
        BigNumber.from('450000000000000000000'),
      );
    }
    expect(await pair.balanceOf(addr2.address)).to.equal(67423461417476714728n);
  });
});
