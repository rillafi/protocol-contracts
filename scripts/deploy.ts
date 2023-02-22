import { network, ethers, upgrades } from 'hardhat';

async function main() {
    // Create a Frame connection
    /* const ethProvider = require('eth-provider'); // eth-provider is a simple EIP-1193 provider */
    /* const frame = ethProvider('frame'); // Connect to Frame */
    /**/
    /* // Use `getDeployTransaction` instead of `deploy` to return deployment data */
    /* const Vesting = await ethers.getContractFactory('TokenVesting'); */
    /* const tx = Vesting.getDeployTransaction("0x96D17e1301b31556e5e263389583A9331e6749E9"); */
    /**/
    /* // Set `tx.from` to current Frame account */
    /* tx.from = (await frame.request({ method: 'eth_requestAccounts' }))[0]; */
    /**/
    /* // Sign and send the transaction using Frame */
    /* await frame.request({ method: 'eth_sendTransaction', params: [tx] }); */

    let treasuryAdd = '0x055810805C63dcAc52538706b623B2ea81C9A687';
    let feeAdd = '0x9F8ad024274A2c64f3EB964E8E5a7a447d6FC483';
    let rillaAdd = '0x96D17e1301b31556e5e263389583A9331e6749E9';
    let signer = await ethers.getSigner((network.config as any).deployer);
    console.log(await signer.getChainId());
    /* let dafImplementation = await ethers.getContractFactory( */
    /*     'DAFImplementation', */
    /*     signer */
    /* ); */
    /* let DafImplementation = await dafImplementation.connect(signer).deploy(); */
    /* console.log('DafImplementation: ', DafImplementation.address); */

    let dafImplementationAddress = '0x84Fd358423a68dd7E0080DDD1E42907e8a524Ff7';
    let rillaIndexAdd = '0x2f134c84FfB8A627c8cB37B6caE85564e72f354E';
    await ethers.getContractAt('RillaIndex', rillaIndexAdd);
    let rillaIndexImpl = await ethers.getContractFactory('RillaIndex');
    /* let RillaIndexImpl = await rillaIndexImpl.deploy(); */
    console.log('RillaIndex: ', rillaIndexAdd);
    let RillaIndex = await upgrades.deployProxy(rillaIndexImpl, [
        dafImplementationAddress,
        rillaAdd,
        feeAdd,
        treasuryAdd,
        ethers.BigNumber.from(1e10), // 1 cent swap rate
    ]);
    console.log('RillaIndex: ', RillaIndex.address);
}

main();
