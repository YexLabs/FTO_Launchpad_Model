import * as dotenv from "dotenv";
import { verify } from "./verify-contract";

dotenv.config();

async function main() {
  await verify(
    "0x5c221868bCD2Fb371a0cD0ACedfD63c0C29938A2",
    "contracts/core/USDT.sol:USDT",
    []
  );
  console.log("verify success");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
