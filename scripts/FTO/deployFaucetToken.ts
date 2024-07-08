import * as dotenv from "dotenv";
import { ethers } from "hardhat";
import { verify } from "../verify-contract";

dotenv.config();

async function main() {
  const tokens = [
    {
      name: "BearBerry",
      symbol: "BBY",
      address: "0x215Ce3B0d34FeF10b2BF4564BAb7D6B6b58370Eb",
    },
    {
      name: "BearCub Token",
      symbol: "CUB",
      address: "0x571DF568CA8673f48664878E4821f938EB6D7497",
    },
    {
      name: "PolarBear Coin",
      symbol: "PBC",
      address: "0x5aD8Ad0310cFB7152d7Dc656DD6356E9118f0a95",
    },
    {
      name: "Grizzly Token",
      symbol: "GRZ",
      address: "0x1b32FDe39d379A5105401389c3CfD985958c9d0f",
    },
    {
      name: "Kodiak Coin",
      symbol: "KDK",
      address: "0x756Afd4cA8cE2ef38bD16b8BBB9e39e5e72D1c8c",
    },
    {
      name: "BlackBear Token",
      symbol: "BLK",
      address: "0xf18c4ed3250f4A14279F5f79eD00b5A1Cd0391B0",
    },
    {
      name: "MoonBear Coin",
      symbol: "MBC",
      address: "0xC4c2FB9dC086eeD9F463CF717875a869C36459b1",
    },
    {
      name: "BrownBear Token",
      symbol: "BRN",
      address: "0x039eCEfb770ae0eb370d9dbb5cb42218C2Ae98D6",
    },
    {
      name: "SpiritBear Coin",
      symbol: "SPR",
      address: "0xc961e26393B4A2301b8e23Ee004A23C856153A49",
    },
    {
      name: "BearClaw Token",
      symbol: "CLW",
      address: "0x1bFF2BA9ee0FFC1e55c0Eb475575A15E1Cf9D6cc",
    },
    {
      name: "BearHug Coin",
      symbol: "HUG",
      address: "0xB3E96499253f634348578a792452c1B8e9dE9ADF",
    },
    {
      name: "HoneyPot Bear Token",
      symbol: "HPB",
      address: "0x34DD3Fc1A50ec71785FabCdC4bA50f61aAdb7865",
    },
    {
      name: "GoldenBear Coin",
      symbol: "GLD",
      address: "0x2160E65c07aAFD809f4f39a94513a21FbE20b615",
    },
    {
      name: "ArcticBear Token",
      symbol: "ARC",
      address: "0x559066e029787e27153BC99Dcf9E540111F346f4",
    },
    {
      name: "SunBear Coin",
      symbol: "SUN",
      address: "0x77383d6B0f22fdF4A337CE55eE371bf720EbB8B2",
    },
    {
      name: "BearPaw Token",
      symbol: "PAW",
      address: "0x40a43F1c14Ecf0B7F2C30CD63320c7fa11032FF8",
    },
    {
      name: "Ursa Major Coin",
      symbol: "UMC",
      address: "0xB93940ed7aF3471120f27C7aaa10807F61d29e01",
    },
    {
      name: "SleepyBear Token",
      symbol: "ZZZ",
      address: "0x4fdD224DD6A7CcBdeAA7ae1be3257EC10456d042",
    },
    {
      name: "HibernationCoin",
      symbol: "Zzz",
      address: "0x990480166b33aDB38a2fD2701484F5435f2E2fD0",
    },
    {
      name: "BearEssence Token",
      symbol: "BES",
      address: "0x1AcD63C992D7D396Ac6cEba9A21f957e76645B97",
    },
  ];
  const addressList = [];
  for (const token of tokens) {
    const address = await deployERC20Faucet(token.name, token.symbol);
    addressList.push(address);
  }

  for (const address of addressList) {
    console.log(address);
  }
}

export async function deployERC20Faucet(name: string, symbol: string) {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log(
    "Account balance:",
    (await ethers.provider.getBalance(deployer.address)).toString()
  );

  const ERC20Faucet = await ethers.deployContract(
    "contracts/core/ERC20Faucet.sol:ERC20Faucet",
    [name, symbol]
  );
  await ERC20Faucet.deployed();
  console.log(ERC20Faucet.address);

  await verify(
    ERC20Faucet.address,
    "contracts/core/ERC20Faucet.sol:ERC20Faucet",
    [name, symbol]
  );

  return ERC20Faucet.address;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
