import * as dotenv from "dotenv";

import { verify } from "../verify-contract";
dotenv.config();

async function main() {
  await verifyFTOFactory();
}

async function verifyFTOFactory() {
  const v1 = verify(
    "0xad88D4ABbE0d0672f00eB3B83E6518608d82e95d",
    "contracts/core/YexFTOFactory.sol:YexFTOFactory",
    []
  );
  await v1;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
