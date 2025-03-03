import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ignition";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config"; // Ensure dotenv is imported

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "", // Fallback to empty string if undefined
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    mainnet: {
      url: process.env.MAINNET_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    core: {
      url: "https://rpc.coredao.org", // Core DAO mainnet RPC
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    coreTestnet: {
      url: "https://rpc.test.btcs.network", // Core DAO testnet RPC
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    forking: {
      url: process.env.SEPOLIA_RPC_URL || "", 
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY, // Move this outside 'networks'
  },
  sourcify: {
    enabled: false,
  },
};

export default config;
