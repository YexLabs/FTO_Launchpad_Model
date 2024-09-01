import * as dotenv from 'dotenv';
import * as hre from 'hardhat';
import { verify } from '../verify-contract';
dotenv.config();

async function main() {
  await deployRouterV1(
    '0xBd650D068a02F1A0Bf12EE94c3517471B7CaF8fD',
    '0x7507c1dc16935B82698e4C63f2746A2fCf994dF8',
  );
}

async function deployRouterV1(factoryContractAddy: any, WETHAddy: any) {
  const router02 = await hre.ethers.getContractFactory('HenloDexRouterV2');
  const router02Contract = await router02.deploy(factoryContractAddy, WETHAddy);

  await router02Contract.deployed();
  console.log(
    `HenloDexRouterV2 contract deployed to ${router02Contract.address}`,
  );

  console.log('Waiting for blocks confirmations...');
  await router02Contract.deployTransaction.wait(6);
  console.log('Confirmed!');

  await verify(
    router02Contract.address,
    'contracts/periphery/HenloDexRouterV2.sol:HenloDexRouterV2',
    [factoryContractAddy, WETHAddy],
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
