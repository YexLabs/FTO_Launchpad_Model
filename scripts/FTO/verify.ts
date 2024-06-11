import * as dotenv from "dotenv";

import { verify } from "../verify-contract";
dotenv.config();

async function main() {
  await verifyFTOFactory();
}

async function verifyFTOFactory() {
  const v1 = verify("0xf53f1eFd3bD5AaCBcc05BeDA45b43c3F16e2B77F", []);
  await v1;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
