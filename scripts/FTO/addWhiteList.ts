import * as dotenv from 'dotenv';
import * as hre from 'hardhat';
dotenv.config();

async function main() {
  const factoryAddr = '0x5C4cDd0160c0CB4C606365dD98783064335A9ce0';
  await addWhiteList(factoryAddr, [
    '0x5f3A01f06B90F3f766121802E783E1Fb0EA06ce4',
    '0x0Cf22E5505CEeBbdC10fFe5CB44c332aA1268e1F',
    '0x5a2fbb577C629Ca7329277b343bB9A22f760aadf',
    '0x9a72f8af03fC25a119C9e8eDaA4329cD8C65cd79',
    '0x2D764DFeaAc00390c69985631aAA7Cc3fcfaFAfF',
    '0xdc7B6B124A8F951D1c12667c21B0eB7F61CEfE42',
    '0x7e0af8f2df7f6d21aea5b90b62ee5832f7c0db20',
    '0xD896C7c5b9557e51c6339680bb9cab817299305C',
    '0xEBfE1c185a3E949843935b47626e575D06Af42F2',
    '0x825527248a9fF9fa7CdA8FEB234c819276D973d4',
    '0xCe8D4e158981c4BB9B830FD729E415B5F7b666aF',
    '0x2Cf996EfbFBfB23B991b15b49212B6b4CE8Bd21e',
    '0x2F14D9a97E6b121737AfB6aB7DeF28cf1346b299',
  ]);
}

async function addWhiteList(factoryContractAddy: any, addressList: string[]) {
  const YexFTOFactory = await hre.ethers.getContractFactory('YexFTOFactory');
  const YexFTOFactoryContract = YexFTOFactory.attach(factoryContractAddy);
  const addTx = await YexFTOFactoryContract.batchAddWhiteList(addressList);

  await addTx.wait(6);
  console.log(addTx.hash);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
