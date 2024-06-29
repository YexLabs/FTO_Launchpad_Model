import * as dotenv from "dotenv";
import * as hre from "hardhat";
dotenv.config();

async function main() {
  const henloDexRouter = "0x482270069fF98a0dF528955B651494759b3B2F8C";
  const HenloDex = await hre.ethers.getContractFactory("HenloDexRouterV1");
  const henloDex = HenloDex.attach(henloDexRouter);
  const swapTx = await henloDex.swapExactTokensForTokens(
    1000000000000000000n,
    977286454053090685862n,
    [
      "0x2a108225249cb5b3e1e33943f5fefaec33b1d452",
      "0x754b8de5014138875a8432a2632f414c924cf395",
    ],
    "0x8ef3fd2bf7ae8a190e437aa6248d419c34428804",
    1000000000000000n
  );
  console.log(swapTx.hash);
  await swapTx.wait(1);
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
