import * as dotenv from "dotenv";
import * as hre from "hardhat";
import { verify } from "./verify-contract";
dotenv.config();

async function main() {
  await deployRouter02(
    "0xE0D1F1cE03A7598EE7FdF7E5DB837d9726C0Ea5c",
    "0x5806E416dA447b267cEA759358cF22Cc41FAE80F"
  );
}

async function deployRouter02(factoryContractAddy: any, WETHAddy: any) {
  const router02 = await hre.ethers.getContractFactory("UniswapV2Router02");
  const router02Contract = await router02.deploy(factoryContractAddy, WETHAddy);

  await router02Contract.deployed();
  console.log(
    `UniswapV2Router02 contract deployed to ${router02Contract.address}`
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
