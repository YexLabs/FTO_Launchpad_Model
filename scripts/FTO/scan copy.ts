import * as dotenv from "dotenv";
import { ethers } from "hardhat";

dotenv.config();

async function main() {
  scanUpKeep();
}

async function scanUpKeep() {
  const pair = "0xbf3B21fDCCf6D6F2f0e9DCd41E7f45D690A876aA";

  const FTOPair = await ethers.getContractFactory("YexFTOPair");
  const ftoPairContract = FTOPair.attach(pair);

  const raised = await ftoPairContract.launchedToken();

  console.log(raised.toString());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
