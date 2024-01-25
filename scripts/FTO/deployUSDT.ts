import * as dotenv from "dotenv";
import { ethers } from "hardhat";
import { verify } from "../verify-contract";

dotenv.config();

async function main() {
  await deployUSDT();
}

export async function deployUSDT() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log(
    "Account balance:",
    (await ethers.provider.getBalance(deployer.address)).toString()
  );

  const ERC20Mintable = await ethers.deployContract(
    "contracts/core/USDT.sol:USDT",
    []
  );
  await ERC20Mintable.deployed();
  console.log(ERC20Mintable.address);

  await verify(ERC20Mintable.address, "contracts/core/USDT.sol:USDT", []);

  return ERC20Mintable.address;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
