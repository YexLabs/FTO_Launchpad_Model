import * as dotenv from "dotenv";

import { ethers } from "hardhat";
import { verify } from "../verify-contract";
dotenv.config();

async function main() {
  await deployFTOFactory();
}

async function deployFTOFactory() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const FTOFactory = await ethers.getContractFactory("YexFTOFactory");
  const ftoFactoryContract = await FTOFactory.deploy([]);
  console.log(`FTOFactory contract deployed to ${ftoFactoryContract.address}`);

  await ftoFactoryContract.deployed();

  console.log("Waiting for blocks confirmations...");
  await ftoFactoryContract.deployTransaction.wait(10);
  console.log("Confirmed!");

  console.log("INIT_HASH_CODE", await ftoFactoryContract.INIT_CODE_PAIR_HASH());
  const v1 = verify(
    ftoFactoryContract.address,
    "contracts/core/YexFTOFactory.sol:YexFTOFactory",
    []
  );
  await v1;

  const setUpTx = await ftoFactoryContract.setNoWhiteList(true);

  await setUpTx.wait(6);

  return ftoFactoryContract.address;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
