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
                runs: 200,
            },
        },
    },
    vyper: {
        compilers: [{ version: '0.2.4' }, { version: '0.2.7' }],
    },
    namedAccounts: { deployer: '0x5117438e943ab870625dda4B0FE3b8118640fFdb' },
    networks: {
        hardhat: {
            chainId: 31337,
            forking: {
                // url: `https://opt-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY_OPTIMISM}`,
                url: `https://optimism-mainnet.infura.io/v3/964b41ffb98d46fe84be73c6ff77d549`,
            },
            accounts: {
                mnemonic: process.env.MNEMONIC 
            },
        },
        optimism: {
            // url: `https://optimism-mainnet.infura.io/v3/964b41ffb98d46fe84be73c6ff77d549`,
            url: 'http://127.0.0.1:1248',
            chainId: 10,
            timeout: 60000,
            // accounts: {
                // mnemonic: process.env.MNEMONIC 
            // },
        },
    },
    etherscan: {
        apiKey: {
            goerli: 'GS67RJI5VR8XPRSRA63HCRNSKPXR2PEG9M',
            optimisticEthereum: 'HN6JR2WJF6TFI6X8IK4TUBIB3J254VBWTU',
        },
    },
};
