import * as dotenv from "dotenv";
import * as hre from "hardhat";
import { verify } from "../verify-contract";
dotenv.config();

async function main() {
  const factoryAddr = "0x13Db24fF75a7FB3Cc22Fa938c3a07C5938A7d0cD";
  await deployFTOFacade(factoryAddr);
}

async function deployFTOFacade(factoryContractAddy: any) {
  const YexFTOFacade = await hre.ethers.getContractFactory("YexFTOFacade");
  const yexFTOFacadeContract = await YexFTOFacade.deploy(factoryContractAddy);

  await yexFTOFacadeContract.deployed();
  console.log(
    `YexFTOFacade contract deployed to ${yexFTOFacadeContract.address}`
  );

  console.log("Waiting for blocks confirmations...");
  await yexFTOFacadeContract.deployTransaction.wait(10);
  console.log("Confirmed!");

  await verify(yexFTOFacadeContract.address, [factoryContractAddy]);

  return yexFTOFacadeContract.address;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
