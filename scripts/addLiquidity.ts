import * as dotenv from "dotenv";
import * as hre from "hardhat";
dotenv.config();

async function main() {
  const router02 = await hre.ethers.getContractFactory("UniswapV2Router02");
  const router02Contract = router02.attach(
    "0xBF5BB6e4189877bA03168035a56CBC452f59c0d2"
  );

  // usdt: 0x5c221868bCD2Fb371a0cD0ACedfD63c0C29938A2
  const addTx = await router02Contract.addLiquidity(
    "0x8D7888e52A8661830357d131A675Da6Cbd470C0D",
    "0x5d116b0032188519e62858dFd3b7917ccEcad170",
    5000000000000000000n,
    5000000000000000000n,
    0,
    0,
    "0x8Ef3fd2Bf7ae8A190E437Aa6248D419c34428804",
    10000000000000000000n
  );

  addTx.wait(4);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
