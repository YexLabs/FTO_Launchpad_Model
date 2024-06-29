import * as dotenv from "dotenv";
import * as hre from "hardhat";
import { verify } from "./verify-contract";
dotenv.config();

async function main() {
  const factoryAddy = await deployFactory(process.env.FEE_WALLET);
  console.log(factoryAddy);
}

async function deployFactory(feeWalletAddy: any) {
  const factory = await hre.ethers.getContractFactory("HenloDexFactory");
  const factoryContract = await factory.deploy(feeWalletAddy);

  console.log(factoryContract.address);
  await factoryContract.deployed();
  console.log(
    `HenloDexFactory contract deployed to ${factoryContract.address}`
  );

  console.log("Waiting for blocks confirmations...");
  await factoryContract.deployTransaction.wait(6);
  console.log("Confirmed!");

  console.log("INIT_HASH_CODE", await factoryContract.INIT_CODE_PAIR_HASH());

  await verify(factoryContract.address, [process.env.FEE_WALLET]);

  return factoryContract.address;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
