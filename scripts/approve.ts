import * as dotenv from "dotenv";
import * as hre from "hardhat";
dotenv.config();

async function main() {
  const usdt = await hre.ethers.getContractFactory("USDT");
  const usdtContract = usdt.attach(
    "0x5c221868bCD2Fb371a0cD0ACedfD63c0C29938A2"
  );

  await usdtContract.approve(
    "0xbe02ffd42ef290c3d9890b5e6b5c215305dbd3f0",
    20000000000000000000n,
  );

  const sol = await hre.ethers.getContractFactory("SOL");
  const solContract = sol.attach("0x649f54532f39a825FEfF83e2e52036E666bc03C7");

  await solContract.approve(
    "0xbe02ffd42ef290c3d9890b5e6b5c215305dbd3f0",
    20000000000000000000n
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
