import "@nomicfoundation/hardhat-toolbox";
import 'hardhat-storage-layout';
import * as dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "solidity-coverage";
import 'solidity-docgen';
dotenv.config();

task('storageLayout', 'Prints the storage layout of the contract')
  .addOptionalParam('contractname', 'The name of the contract')
  .setAction(async (taskArgs, hre) => {
    const contractName = taskArgs.contractname;
    if (contractName) {
      const layout = await hre.storageLayout.export(contractName);
      console.log(JSON.stringify(layout, null, 2));
    } else {
      const layout = await hre.storageLayout.export();
      console.log(JSON.stringify(layout, null, 2));
    }
  });

const config: HardhatUserConfig = {
  gasReporter: {
    enabled: true,
  },
  solidity: {
    version: "0.8.16",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    zkscroll: {
      url: "https://rpc.scroll.io",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    scrollAlpha: {
      url: process.env.SCROLL_TESTNET_URL || "https://alpha-rpc.scroll.io/l2",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    goerli: {
      url: process.env.GOERLI_TESTNET_URL || "https://rpc.ankr.com/eth_goerli",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    polygon_mumbai: {
      url: "https://rpc.ankr.com/polygon_mumbai",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    polygon: {
      url: "https://polygon-rpc.com",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    sepolia: {
      url: "https://rpc-sepolia.rockx.com",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    sepolia_scroll: {
      url: "https://sepolia-rpc.scroll.io",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    mainnet: {
      url: "https://ethereum.publicnode.com",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    berachainArtio: {
      url: "https://artio.rpc.berachain.com",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    berachainBrtio: {
      url: "https://bartio.rpc.berachain.com",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: {
      zkscroll: "abc",
      sepolia_scroll: "YourApiKeyToken",
      scrollAlpha: "abc",
      polygon_mumbai:
        process.env.MUMBAISCAN_API_KEY !== undefined
          ? process.env.MUMBAISCAN_API_KEY
          : "",
      polygon:
        process.env.MUMBAISCAN_API_KEY !== undefined
          ? process.env.MUMBAISCAN_API_KEY
          : "",
      sepolia:
        process.env.SEPOLIASCAN_API_KEY !== undefined
          ? process.env.SEPOLIASCAN_API_KEY
          : "",
      goerli:
        process.env.GOERLISCAN_API_KEY !== undefined
          ? process.env.GOERLISCAN_API_KEY
          : "",
      berachainArtio: "XXX",
      berachainBrtio: "XXX",
    },
    customChains: [
      {
        network: "mainnet",
        chainId: 1,
        urls: {
          apiURL: "https://ethereum.publicnode.com",
          browserURL: "https://etherscan.io/",
        },
      },
      {
        network: "goerli",
        chainId: 5,
        urls: {
          apiURL: "https://api-goerli.etherscan.io/api",
          browserURL: "https://goerli.etherscan.io/",
        },
      },
      {
        network: "scrollAlpha",
        chainId: 534353,
        urls: {
          apiURL: "https://alpha-blockscout.scroll.io/api",
          browserURL: "https://alpha-blockscout.scroll.io/",
        },
      },
      {
        network: "zkscroll",
        chainId: 534352,
        urls: {
          apiURL: "https://blockscout.scroll.io/api",
          browserURL: "https://blockscout.scroll.io/",
        },
      },
      {
        network: "sepolia",
        chainId: 11155111,
        urls: {
          apiURL: "https://api-sepolia.etherscan.io/api",
          browserURL: "https://sepolia.etherscan.io/",
        },
      },
      {
        network: "sepolia_scroll",
        chainId: 534351,
        urls: {
          apiURL: "https://api-sepolia.scrollscan.com/api",
          browserURL: "https://sepolia.scrollscan.com/",
        },
      },
      {
        network: "polygon_mumbai",
        chainId: 80001,
        urls: {
          apiURL: "https://api-testnet.polygonscan.com/api",
          browserURL: "https://mumbai.polygonscan.com/",
        },
      },
      {
        network: "polygon",
        chainId: 137,
        urls: {
          apiURL: "https://api.polygonscan.com/api",
          browserURL: "https://polygonscan.com/",
        },
      },
      {
        network: "berachainArtio",
        chainId: 80085,
        urls: {
          apiURL:
            "https://api.routescan.io/v2/network/testnet/evm/80085/etherscan/api",
          browserURL: "https://artio.beratrail.io/",
        },
      },
      {
        network: "berachainBrtio",
        chainId: 80084,
        urls: {
          apiURL:
            "https://api.routescan.io/v2/network/testnet/evm/80084/etherscan/api",
          browserURL: "https://bartio.beratrail.io/",
        },
      },
    ],
  },
  docgen: {
      pages: 'files',
      exclude: ['interfaces', 'libraries', 'periphery'],
  }
};
export default config;
