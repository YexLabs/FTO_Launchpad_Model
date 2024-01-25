import * as dotenv from "dotenv";
import * as hre from "hardhat";
dotenv.config();

async function main() {
  const factoryAddr = "0x679580fdf6886a838E0f6b2a1faF38D33145eC35";
  await createFTO(factoryAddr);
}

async function createFTO(factoryContractAddy: any) {
  const YexFTOFactory = await hre.ethers.getContractFactory("YexFTOFactory");
  const YexFTOFactoryContract = YexFTOFactory.attach(factoryContractAddy);
  const usdt = "0xe33ecf950b53dcc429e6127ed1a6a5085e1918fe";
  const poolHandler = "0x2f2f7197d19a13e8c72c1087dd29d555abe76c5c";
  const createTx = await YexFTOFactoryContract.createFTO(
    usdt,
    "SECOND",
    "SC",
    1000000000000000000000n,
    poolHandler,
    500
  );

  console.log(createTx.hash);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// FTOfacade: 0xF5D9E83fd470a9641B5dD3C67D8d6D246F589F8A
// FTOfactory: 0x679580fdf6886a838E0f6b2a1faF38D33145eC35
// usdt: 0xe33ecf950b53dcc429e6127ed1a6a5085e1918fe
// router02: 0x2f2f7197d19A13e8c72c1087dD29d555aBE76C5C
