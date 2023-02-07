import { task } from 'hardhat/config';
import '@openzeppelin/hardhat-upgrades';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-vyper';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-change-network';
import 'hardhat-contract-sizer';
import dotenv from 'dotenv';
// import "./tasks/deploy";
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

dotenv.config();

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
export default {
    solidity: {
        version: '0.8.16',
        settings: {
            optimizer: {
                enabled: true,
                runs: 9999,
            },
        },
    },
    vyper: {
        compilers: [{ version: '0.2.4' }, { version: '0.2.7' }],
    },
    networks: {
        hardhat: {
            chainId: 31337,
            forking: {
                url: `https://opt-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY_OPTIMISM}`,
            },
        },
        // goerli: {
        //   url: `https://eth-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_KEY_GOERLI}`,
        //   accounts: {
        //     mnemonic: process.env.MNEMONIC,
        //     path: "m/44'/60'/0'/0",
        //     initialIndex: 0,
        //     count: 20,
        //     passphrase: "",
        //   },
        //  },
    },
    etherscan: {
        apiKey: {
            goerli: 'GS67RJI5VR8XPRSRA63HCRNSKPXR2PEG9M',
            optimisticEthereum: 'HN6JR2WJF6TFI6X8IK4TUBIB3J254VBWTU',
        },
    },
};
