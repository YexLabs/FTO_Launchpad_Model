import * as dotenv from "dotenv";
import * as hre from "hardhat";
dotenv.config();

async function main() {
  //   const sol = await hre.ethers.getContractFactory("SOL");
  //   const solContract = sol.attach("0x8D7888e52A8661830357d131A675Da6Cbd470C0D");

  //   const tx = await solContract.faucet();
  //   await tx.wait(4);

  const usdt = await hre.ethers.getContractFactory("USDT");
  const usdtContract = usdt.attach(
    "0x5d116b0032188519e62858dFd3b7917ccEcad170"
  );

  const tx1 = await usdtContract.faucet();
  await tx1.wait(4);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
