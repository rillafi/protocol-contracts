import { ethers } from 'hardhat';
import { Signer, Contract, BigNumber, BigNumberish } from 'ethers';
import { expect } from 'chai';

describe('DAF', function () {
    let accounts: Signer[];
    let addys: string[];

    let Rilla: Contract;
    before(async function () {
        accounts = await ethers.getSigners();
        addys = await Promise.all(accounts.map((acc) => acc.getAddress()));
        // Deploy Contracts
        let rilla = await ethers.getContractFactory('RILLA');
        Rilla = await rilla.deploy();
    });

    it('Mints all tokens to deployer', async function () {
        const bal = await Rilla.balanceOf(addys[0]);
        console.log(bal);
    });
});
