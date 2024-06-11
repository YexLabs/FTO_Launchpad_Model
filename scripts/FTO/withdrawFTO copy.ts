import * as dotenv from "dotenv";
import * as hre from "hardhat";
dotenv.config();

async function main() {
  const ftoFactoryAddr = "0xEd6a0A29A962B4296bCeEC4e1E55F5Ec0474EAC7";
  // await createTokenA();
  const tokenAAddr = "0x5806E416dA447b267cEA759358cF22Cc41FAE80F";
  // console.log(ftoFactoryAddy)
  // await mintTokenA();
  await withdraw(ftoFactoryAddr, tokenAAddr);
}

async function withdraw(ftoFactoryAddr: any, tokenAAddr: any) {
  const FTOFactory = await hre.ethers.getContractFactory("YexFTOFactory");
  const ftocadeContract = FTOFactory.attach(ftoFactoryAddr);
  const withdraw = await ftocadeContract.addRaisedToken(tokenAAddr);
  console.log(`withdraw at ${withdraw.hash}`);

  console.log("Waiting for blocks confirmations...");
  await withdraw.wait(3);
  console.log("Confirmed!");
}

async function createFTO(ftoFactoryAddr: any, tokenAAddr: any) {
  const FTOFactory = await hre.ethers.getContractFactory("YexFTOFactory");
  const ftocadeContract = FTOFactory.attach(ftoFactoryAddr);
  const withdraw = await ftocadeContract.createFTO(
    "0x8ef3fd2bf7ae8a190e437aa6248d419c34428804",
    tokenAAddr,
    "test",
    "test",
    10000000000,
    "0xB192af2225791c439CB2024290158d3202DbcD95",
    1000
  );
  console.log(`createFTO at ${withdraw.hash}`);

  console.log("createFTO for blocks confirmations...");
  await withdraw.wait(3);
  console.log("Confirmed!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
