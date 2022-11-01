import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "hardhat-abi-exporter";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import '@openzeppelin/hardhat-upgrades';
import "hardhat-contract-sizer";

dotenv.config();


task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task("printTime", "Increases the current time", async (taskArgs: any, hre) => {
  const latestBlock = await hre.ethers.provider.getBlock("latest");
  console.log(latestBlock.timestamp);
});

task("mineBlock", "Mines block", async (taskArgs: any, hre) => {
  await hre.ethers.provider.send('evm_mine', []);
});

task("increaseTime", "Increases the current time", async (taskArgs: any, hre) => {
  await hre.ethers.provider.send('evm_increaseTime', [Number(taskArgs.timeOffset)]);
  await hre.ethers.provider.send('evm_mine', []);
  const latestBlock = await hre.ethers.provider.getBlock("latest");
  console.log(latestBlock.timestamp);
}).addPositionalParam('timeOffset');

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1,
      },
    },
  },
  networks: {
    matic: {
      url: process.env.MATIC_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  abiExporter: {
    path: './abi',
    runOnCompile: true,
    clear: true,
    flat: true,
    spacing: 2,
    pretty: false,
  }
};

export default config;
