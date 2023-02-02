import { ethers } from 'hardhat';

async function main() {
    // Create a Frame connection
    const ethProvider = require('eth-provider'); // eth-provider is a simple EIP-1193 provider
    const frame = ethProvider('frame'); // Connect to Frame

    // Use `getDeployTransaction` instead of `deploy` to return deployment data
    const Vesting = await ethers.getContractFactory('TokenVesting');
    const tx = Vesting.getDeployTransaction("0x96D17e1301b31556e5e263389583A9331e6749E9");

    // Set `tx.from` to current Frame account
    tx.from = (await frame.request({ method: 'eth_requestAccounts' }))[0];

    // Sign and send the transaction using Frame
    await frame.request({ method: 'eth_sendTransaction', params: [tx] });
}

main()
