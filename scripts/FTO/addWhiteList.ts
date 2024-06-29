import * as dotenv from "dotenv";
import * as hre from "hardhat";
dotenv.config();

async function main() {
  const factoryAddr = "0x5C4cDd0160c0CB4C606365dD98783064335A9ce0";
  await addWhiteList(factoryAddr, [
    "0xd51A2F6434cB702e0B0a6CD9e70e33B720d403F3",
    "0x630866b8333D5FA1dFa6b6483786c606dD7d7a93",
  ]);
}

async function addWhiteList(factoryContractAddy: any, addressList: string[]) {
  const YexFTOFactory = await hre.ethers.getContractFactory("YexFTOFactory");
  const YexFTOFactoryContract = YexFTOFactory.attach(factoryContractAddy);
  const addTx = await YexFTOFactoryContract.batchAddWhiteList(addressList);

  await addTx.wait(6);
  console.log(addTx.hash);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
