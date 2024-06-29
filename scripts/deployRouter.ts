import * as dotenv from "dotenv";
import * as hre from "hardhat";
import { verify } from "./verify-contract";
dotenv.config();

async function main() {
  await deployRouter02(
    "0x2f795195bae7E61E848ffC87ba7f6ae1A06c0527",
    "0x7507c1dc16935B82698e4C63f2746A2fCf994dF8"
  );
}

async function deployRouter02(factoryContractAddy: any, WETHAddy: any) {
  const router02 = await hre.ethers.getContractFactory("HenloDexRouterV1");
  const router02Contract = await router02.deploy(factoryContractAddy, WETHAddy);

  await router02Contract.deployed();
  console.log(
    `HenloDexRouterV1 contract deployed to ${router02Contract.address}`
  );

  console.log("Waiting for blocks confirmations...");
  await router02Contract.deployTransaction.wait(6);
  console.log("Confirmed!");

  await verify(router02Contract.address, [factoryContractAddy, WETHAddy]);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
