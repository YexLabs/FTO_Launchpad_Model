import * as dotenv from 'dotenv';
import * as hre from 'hardhat';
dotenv.config();

async function main() {
  // need to configure FTO_FACTORY adress
  const factoryAddr = process.env.FTO_FACTORY;
  const YexFTOFactory = await hre.ethers.getContractFactory('YexFTOFactory');
  const YexFTOFactoryContract = YexFTOFactory.attach(factoryAddr || '');
  const len = await YexFTOFactoryContract.allPairsLength();
  console.log(len);

  for (let i = 0; i < len; i++) {
    const pair = await YexFTOFactoryContract.allPairs(i);
    console.log(i + ':' + pair);
    await perform(pair);
  }
}

async function perform(pair: string) {
  const YexFTOPair = await hre.ethers.getContractFactory('YexFTOPair');
  const pairContract = YexFTOPair.attach(pair);
  const state = await pairContract.FTOState();
  if (state === 2) {
    const res = await pairContract.checkUpkeep('0x');
    console.log(res.upkeepNeeded);
    if (res.upkeepNeeded) {
      try {
        const performUpTx = await pairContract.performUpkeep('0x');
        await performUpTx.wait(10);
      } catch (error) {
        console.log('error pair', pair);
        console.log(error);
      }
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
