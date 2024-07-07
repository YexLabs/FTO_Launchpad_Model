import * as dotenv from "dotenv";
import { ethers } from "hardhat";

dotenv.config();

async function main() {
  // setInterval(scanUpKeep, 1000 * 60);
  setTimeout(async function run() {
    await scanUpKeep();
    setTimeout(run, 1000);
  }, 1000);
  // scanUpKeep();
}

async function scanUpKeep() {
  const factory = "0x16b7e526cE35061de7c26E6D943687460637BB6D";

  const FTOFactory = await ethers.getContractFactory("YexFTOFactory");
  const FTOPair = await ethers.getContractFactory("YexFTOPair");
  const ftoFactoryContract = FTOFactory.attach(factory);

  const len: number = await ftoFactoryContract.allPairsLength();
  console.log(len);
  for (let i = 0; i < len; i++) {
    const pair: string = await ftoFactoryContract.allPairs(i);
    console.log(pair);
    const pairContract = FTOPair.attach(pair);
    const ftoState = await pairContract.FTOState();
    console.log(ftoState);
    // console.log(await pairContract.participations());
    if (ftoState == 3) {
      const { upkeepNeeded } = await pairContract.checkUpkeep("0x");
      console.log(upkeepNeeded);
      if (upkeepNeeded) {
        console.log("perform");
        await pairContract.performUpkeep("0x");
      }
    }
  }

  //   for (const pair of pairs) {
  //     const pairContract = FTOPair.attach(pair);
  //     const [upkeepNeeded, bytesdata] = pairContract.checkUpkeep("0x");
  //     console.log(upkeepNeeded, bytesdata);
  //   }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
