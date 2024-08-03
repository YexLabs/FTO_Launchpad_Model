import { ethers } from 'hardhat';

const deployContracts = async () => {
  const [feeToSetter] = await ethers.getSigners();
  const usdt = await ethers
    .getContractFactory('ERC20Faucet')
    .then((factory) => factory.deploy('usdt', 'usdt'));

  // FTO
  const yexFTOFactory = await ethers
    .getContractFactory('YexFTOFactoryV2')
    .then((factory) => factory.deploy());

  await yexFTOFactory.addRaisedToken(usdt.address);

  const yexFTOFacade = await ethers
    .getContractFactory('YexFTOFacadeV2')
    .then((factory) => factory.deploy(yexFTOFactory.address));

  // HenloDex
  const henloDexFactory = await ethers
    .getContractFactory('HenloDexFactory')
    .then((factory) => factory.deploy(feeToSetter.address));

  const henloDexRouter = await ethers
    .getContractFactory('HenloDexRouterV2')
    .then((factory) => factory.deploy(henloDexFactory.address, usdt.address));

  const bera = await ethers
    .getContractFactory('ERC20Faucet')
    .then((factory) => factory.deploy('bera', 'bera'));

  return {
    usdt,
    yexFTOFactory,
    yexFTOFacade,
    henloDexFactory,
    henloDexRouter,
    bera,
  };
};

const deployERC20Token = async (name: string, symbol: string) => {
  const token = await ethers
    .getContractFactory('ERC20Faucet')
    .then((factory) => factory.deploy(name, symbol));

  await token.deployed();

  return token;
};

export { deployContracts, deployERC20Token };
