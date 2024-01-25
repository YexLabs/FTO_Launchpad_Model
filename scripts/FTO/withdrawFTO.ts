import * as dotenv from "dotenv";
import * as hre from "hardhat";
dotenv.config();

async function main() {
  const ftoFacadeAddr = "0xc961e26393B4A2301b8e23Ee004A23C856153A49";
  // await createTokenA();
  const tokenAAddr = "0x0520b56FBb2B62D025455Da662A2b9a3eAcc78D8";
  const tokenBAddr = "0x9F9F5c7AA988351399c766C194EC59a8b9e4fC50";
  // console.log(ftoFactoryAddy)
  // await mintTokenA();
  await withdraw(ftoFacadeAddr, tokenAAddr, tokenBAddr);
}

async function withdraw(ftoFacadeAddr: any, tokenAAddr: any, tokenBAddr: any) {
  const FTOFacade = await hre.ethers.getContractFactory("YexFTOFacade");
  const ftocadeContract = FTOFacade.attach(ftoFacadeAddr);
  const withdraw = await ftocadeContract.withdraw(tokenAAddr, tokenBAddr);
  console.log(`withdraw at ${withdraw.hash}`);

  console.log("Waiting for blocks confirmations...");
  await withdraw.wait(3);
  console.log("Confirmed!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
