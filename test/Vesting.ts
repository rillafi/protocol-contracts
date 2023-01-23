import { ethers } from 'hardhat';
import { Signer, Contract, BigNumber } from 'ethers';
import { expect } from 'chai';
import { time } from '@nomicfoundation/hardhat-network-helpers';

function delay(time: number) {
    return new Promise((resolve) => setTimeout(resolve, time));
}

describe('Vesting', function () {
    const MAXTIME = 4 * 365 * 86400;

    let accounts: Signer[];
    let addys: String[];
    let deployer;
    let user: Signer;
    let depAdd: String;
    let userAdd: String;
    let token: Contract;
    let feeDist: Contract;
    let vesting: Contract;

    before(async function () {
        // await deploy();
        accounts = await ethers.getSigners();
        addys = await Promise.all(accounts.map((acc) => acc.getAddress()));
        deployer = accounts[0];
        user = accounts[1];
        depAdd = addys[0];
        userAdd = addys[1];

        const Token = await ethers.getContractFactory('RILLA');
        token = await Token.deploy();

        /* const FeeDist = await ethers.getContractFactory('FeeDistributor'); */
        /* feeDist = await FeeDist.deploy( */
        /*     veToken.address, */
        /*     Math.floor(Date.now() / 1000), */
        /*     token.address, */
        /*     depAdd, */
        /*     depAdd */
        /* ); */

        const Vesting = await ethers.getContractFactory('TokenVesting');
        vesting = await Vesting.deploy(token.address);
    });

    it('Vesting: tokens must be in contract first', async function () {
        // * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
        // * @param _start start time of the vesting period
        // * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
        // * @param _duration duration in seconds of the period in which the tokens will vest
        // * @param _slicePeriodSeconds duration of a slice period for the vesting in seconds
        // * @param _revocable whether the vesting is revocable or not
        // * @param _amount total amount of tokens to be released at the end of the vesting
        await expect(
            vesting.functions.createVestingSchedule(
                userAdd,
                Math.floor(Date.now() / 1000),
                0,
                100,
                1,
                false,
                ethers.BigNumber.from('1000000' + '0'.repeat(18))
            )
        ).to.be.reverted;
    });

    it('Vesting: transfers tokens to vesting contract', async function () {
        await token.functions.transfer(
            vesting.address,
            ethers.BigNumber.from('1000000' + '0'.repeat(18))
        );
        const bal = await token.functions.balanceOf(vesting.address);
        expect(bal[0]).to.equal(
            ethers.BigNumber.from('1000000' + '0'.repeat(18))
        );
    });

    it('Vesting: vest successfully created', async function () {
        const duration = 4 * 365 * 86400;
        await vesting.functions.createVestingSchedule(
            userAdd,
            Math.floor(Date.now() / 1000),
            0,
            duration,
            1,
            false,
            ethers.BigNumber.from('1000000' + '0'.repeat(18))
        );
    });

    it("Vesting: doesn't overallocate tokens in vesting contract", async function () {
        const duration = 4 * 365 * 86400;
        await expect(
            vesting.functions.createVestingSchedule(
                userAdd,
                Math.floor(Date.now() / 1000),
                0,
                duration,
                1,
                false,
                ethers.BigNumber.from('1000000' + '0'.repeat(18))
            )
        ).to.be.reverted;
    });

    it('Vesting: creates vests for multiple users', async function () {
        await token.functions.transfer(
            vesting.address,
            ethers.BigNumber.from('1000000' + '0'.repeat(19))
        );
        for (const addy of addys.slice(2, 12)) {
            const duration = 4 * 365 * 86400;
            vesting.functions.createVestingSchedule(
                addy,
                Math.floor(Date.now() / 1000),
                0,
                duration,
                1,
                false,
                ethers.BigNumber.from('1000000' + '0'.repeat(18))
            );
        }
    });

    it('Vesting: increases number of vesting tokens', async function () {
        const _id =
            await vesting.functions.computeVestingScheduleIdForAddressAndIndex(
                userAdd,
                0
            );
        const id = _id[0];
        const prevAmount: BigNumber = await vesting.computeReleasableAmount(id);
        await time.increase(2*365*86400);
        const curAmount: BigNumber = await vesting.computeReleasableAmount(id);
        expect(curAmount.gt(prevAmount))
    });

    it('Vesting: releases tokens', async function () {
        const _id =
            await vesting.functions.computeVestingScheduleIdForAddressAndIndex(
                addys[2],
                0
            );
        const id = _id[0];

        const curAmount: BigNumber = await vesting.computeReleasableAmount(id);
        const prevBal: BigNumber = await token.balanceOf(addys[2]);
        await vesting.connect(accounts[2]).release(id, curAmount);
        const curBal: BigNumber = await token.balanceOf(addys[2]);
        expect(curBal.gt(prevBal));
        expect(curAmount.eq(curBal));
    });

    it('Vesting: does not release tokens to an incorrect account', async function () {
        const _id =
            await vesting.functions.computeVestingScheduleIdForAddressAndIndex(
                addys[3],
                0
            );
        const id = _id[0];

        const curAmount = await vesting.computeReleasableAmount(id);
        const prevBal = await token.balanceOf(addys[3]);

        await expect(vesting.connect(accounts[2]).release(id, curAmount)).to.be
            .reverted;
        const curBal = await token.balanceOf(addys[3]);
        expect(curBal).to.be.equal(prevBal);
    });
});
