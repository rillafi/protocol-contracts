import fetch from 'node-fetch';
import hre, { ethers } from 'hardhat';
import { Signer, Contract } from 'ethers';
import { expect } from 'chai';
import erc20abi from '../abis/erc20abi.json';
import routerabi from '../abis/velodrome/router.json';
import Zeroxabi from '../abis/0x.json';
import tokenList from '../tools/tokenList.json';

function delay(time: number) {
    return new Promise((resolve) => setTimeout(resolve, time));
}

describe('DAF', function () {
    const MAXTIME = 4 * 365 * 86400;

    let dai: Contract;
    let usdc: Contract;
    let DafImplementation: Contract;
    let RillaIndex: Contract;
    let accounts: Signer[];
    let addys: String[];
    let deployer: Signer;
    let user: Signer;
    let depAdd: String;
    let userAdd: String;
    let depositor: Signer;
    let depositorAdd: String;
    let daf: Contract;

    const wethAdd = '0x4200000000000000000000000000000000000006';
    const zeroxAdd = '0xDEF1ABE32c034e558Cdd535791643C58a13aCC10';
    const MAXUINT = ethers.constants.MaxUint256;

    before(async function () {
        dai = await ethers.getContractAt(
            erc20abi,
            '0xda10009cbd5d07dd0cecc66161fc93d7c9000da1'
        );
        usdc = await ethers.getContractAt(
            erc20abi,
            '0x7f5c764cbc14f9669b88837ca1490cca17c31607'
        );

        accounts = await ethers.getSigners();
        addys = await Promise.all(accounts.map((acc) => acc.getAddress()));
        deployer = accounts[0];
        user = accounts[1];
        depAdd = addys[0];
        userAdd = addys[1];

        const accountToImpersonate =
            '0xa3f45e619cE3AAe2Fa5f8244439a66B203b78bCc';
        await hre.network.provider.request({
            method: 'hardhat_impersonateAccount',
            params: [accountToImpersonate],
        });
        // await helpers.impersonateAccount(accountToImpersonate);
        depositor = await ethers.getSigner(accountToImpersonate);
        depositorAdd = await depositor.getAddress();

        // Deploy Contracts
        let dafImplementation = await ethers.getContractFactory(
            'DAFImplementation',
            deployer
        );
        DafImplementation = await dafImplementation.deploy();

        let rillaIndex = await ethers.getContractFactory(
            'RillaIndex',
            deployer
        );
        RillaIndex = await rillaIndex.deploy(DafImplementation.address);
    });

    it('Creates a DAF with one owner', async function () {
        // here
        let tx = await RillaIndex.functions.makeDaf('Test', [addys[0]]);
        let receipt = await tx.wait();
        expect(receipt.events[0].event == 'NewDaf');
        daf = await ethers.getContractAt(
            'DAFImplementation',
            RillaIndex.interface.parseLog(receipt.events[0]).args.newDafAddress
        );
        const ownersDAFs = await RillaIndex.functions.getDAFsForOwner(addys[0]);
        expect(ownersDAFs == [daf.address]);
    });

    it('Prints name of new DAF', async function () {
        console.log(await daf.functions.getOwners());
    })
});
