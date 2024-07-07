import * as dotenv from "dotenv";
import * as hre from "hardhat";
import { verify } from "../verify-contract";
dotenv.config();

async function main() {
  const factoryAddr = "0x4E386552b2ed8E5050A89312Da07C7B9Ee8122c2";
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

  await verify(
    yexFTOFacadeContract.address,
    "contracts/core/YexFTOFacade.sol:YexFTOFacade",
    [factoryContractAddy]
  );

  return yexFTOFacadeContract.address;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
