import * as dotenv from 'dotenv';
import { ethers } from 'hardhat';

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
  const factory = '0xEd6a0A29A962B4296bCeEC4e1E55F5Ec0474EAC7';

  const FTOFactory = await ethers.getContractFactory('YexFTOFactory');
  const FTOPair = await ethers.getContractFactory('YexFTOPair');
  const ftoFactoryContract = FTOFactory.attach(factory);

  const len: number = await ftoFactoryContract.allPairsLength();
  console.log(len);
  for (let i = 0; i < len; i++) {
    const pair: string = await ftoFactoryContract.allPairs(i);
    console.log(i, pair);
    const pairContract = FTOPair.attach(pair);
    const ftoState = await pairContract.FTOState();
    console.log(ftoState);
    // console.log(await pairContract.participations());
    if (ftoState == 3) {
      const { upkeepNeeded } = await pairContract.checkUpkeep('0x');
      console.log(upkeepNeeded);
      if (upkeepNeeded) {
        console.log('perform');
        try {
          const tx = await pairContract.performUpkeep('0x');
          console.log(tx.hash);
        } catch (e) {
          continue;
        }
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
