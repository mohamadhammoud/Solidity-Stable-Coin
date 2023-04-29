import { HardhatUserConfig } from "hardhat/config";
require("dotenv").config();
import "@nomicfoundation/hardhat-toolbox";

import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";

const { PRIVATE_KEY, PUBLIC_KEY, MUMBAI_URL, ALCHEMY_KEY, ETHERSCAN_API_KEY } =
  process.env;

// const config: HardhatUserConfig = {
const config = {
  solidity: {
    compilers: [
      {
        version: "0.8.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    // mumbai: {
    //   url: MUMBAI_URL,
    //   accounts: [`${PRIVATE_KEY}`],
    // },
  },
  etherscan: { apiKey: `${ETHERSCAN_API_KEY}` },
};

export default config;
