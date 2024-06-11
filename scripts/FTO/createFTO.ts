import * as dotenv from "dotenv";
import * as hre from "hardhat";
dotenv.config();

async function main() {
  const factoryAddr = "0x16b7e526cE35061de7c26E6D943687460637BB6D";
  await createFTO(factoryAddr);
}

async function createFTO(factoryContractAddy: any) {
  const YexFTOFactory = await hre.ethers.getContractFactory("YexFTOFactory");
  const YexFTOFactoryContract = YexFTOFactory.attach(factoryContractAddy);
  const usdt = "0x5d116b0032188519e62858dFd3b7917ccEcad170";
  const poolHandler = "0xBF5BB6e4189877bA03168035a56CBC452f59c0d2";
  const createTx = await YexFTOFactoryContract.createFTO(
    "0x8ef3fd2bf7ae8a190e437aa6248d419c34428804",
    usdt,
    "SECOND",
    "SC2",
    1000000000000000000000n,
    poolHandler,
    1787798
  );

  console.log(createTx.hash);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
