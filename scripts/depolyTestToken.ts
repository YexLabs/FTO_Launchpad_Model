import * as dotenv from "dotenv";
import * as hre from "hardhat";
import { verify } from "./verify-contract";
dotenv.config();

async function main() {
  const usdt = await hre.ethers.getContractFactory("USDT");
  const usdtContract = await usdt.deploy();

  await usdtContract.deployed();
  console.log(`usdtContract contract deployed to ${usdtContract.address}`);

  console.log("Waiting for blocks confirmations...");
  await usdtContract.deployTransaction.wait(6);
  console.log("Confirmed!");

  await verify(usdtContract.address, []);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
