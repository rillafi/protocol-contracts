import fetch from 'node-fetch';
import hre, { ethers } from 'hardhat';
import { Signer, Contract, BigNumber, BigNumberish } from 'ethers';
import { expect } from 'chai';
import erc20abi from '../abis/erc20abi.json';
import routerabi from '../abis/velodrome/router.json';
import Zeroxabi from '../abis/0x.json';
import tokenList from '../tools/tokenList.json';
import { time } from '@nomicfoundation/hardhat-network-helpers';

function delay(time: number) {
    return new Promise((resolve) => setTimeout(resolve, time));
}

describe('DAF', function () {
    const MAXTIME = 2 * 365 * 86400;

    let dai: Contract;
    let usdc: Contract;
    let weth: Contract;
    let DafImplementation: Contract;
    let RillaIndex: Contract;
    let Rilla: Contract;
    let VeRilla: Contract;
    let accounts: Signer[];
    let addys: String[];
    let deployer: Signer;
    let user: Signer;
    let feeAcc: Signer;
    let depAdd: String;
    let userAdd: String;
    let feeAdd: String;
    let depositor: Signer;
    let depositorAdd: String;
    let daf: Contract;
    let usdcRichAdd: string = '0xEbe80f029b1c02862B9E8a70a7e5317C06F62Cae';
    let usdcRich: Signer;
    let daiRichAdd: string = '0xc66825C5c04b3c2CcD536d626934E16248A63f68';
    let daiRich: Signer;
    let dafOwnersAddys: String[];
    let dafOwners: Signer[];

    const wethAdd = '0x4200000000000000000000000000000000000006';
    /* const zeroxAdd = '0xDEF1ABE32c034e558Cdd535791643C58a13aCC10'; */
    const usdcAdd = '0x7f5c764cbc14f9669b88837ca1490cca17c31607';
    const daiAdd = '0xda10009cbd5d07dd0cecc66161fc93d7c9000da1';
    const MAXUINT = ethers.constants.MaxUint256;

    async function quote0x(address: string, amount: BigNumber) {
        let searchParams = new URLSearchParams({
            sellToken: address,
            buyToken: usdcAdd,
            sellAmount: amount.toString(),
        });
        let res = await fetch(
            `https://optimism.api.0x.org/swap/v1/quote?${searchParams.toString()}`
        );
        return (await res.json()).data;
    }

    async function feeInCalc(amount: BigNumberish) {
        let fee: BigNumber = await RillaIndex.getInFeeBps();
        return fee.mul(amount).div('10000');
    }

    before(async function () {
        dai = await ethers.getContractAt(erc20abi, daiAdd);
        usdc = await ethers.getContractAt(erc20abi, usdcAdd);
        weth = await ethers.getContractAt(erc20abi, wethAdd);

        accounts = await ethers.getSigners();
        addys = await Promise.all(accounts.map((acc) => acc.getAddress()));
        deployer = accounts[0];
        user = accounts[1];
        depAdd = addys[0];
        userAdd = addys[1];
        feeAcc = accounts[10];
        feeAdd = addys[10];
        [usdcRich, daiRich] = await Promise.all(
            [usdcRichAdd, daiRichAdd].map((elem: string) =>
                hre.network.provider
                    .request({
                        method: 'hardhat_impersonateAccount',
                        params: [elem],
                    })
                    .then(() => ethers.getSigner(elem))
            )
        );
        usdcRichAdd = await usdcRich.getAddress();
        daiRichAdd = await daiRich.getAddress();
        dafOwners = [...accounts.slice(0, 8), usdcRich, daiRich];
        dafOwnersAddys = [...addys.slice(0, 8), usdcRichAdd, daiRichAdd];

        // Deploy Contracts
        let rilla = await ethers.getContractFactory('RILLA', deployer);
        Rilla = await rilla.deploy();

        let veRilla = await ethers.getContractFactory('VoteEscrow', deployer);
        VeRilla = await veRilla.deploy(
            Rilla.address,
            'VeRilla',
            'veRILLA',
            '1.0'
        );

        let dafImplementation = await ethers.getContractFactory(
            'DAFImplementation',
            deployer
        );
        DafImplementation = await dafImplementation.deploy();

        let rillaIndex = await ethers.getContractFactory(
            'RillaIndex',
            deployer
        );
        RillaIndex = await rillaIndex.deploy(
            DafImplementation.address,
            Rilla.address,
            feeAdd
        );

        // addys 0-9 deposit around 1000 veRILLA
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

    /* it('Prints name of new DAF', async function () { */
    /*     console.log(await daf.functions.getOwners()); */
    /*     console.log(await daf.functions.name()); */
    /* }); */

    it('Creates a DAF with multiple owners', async function () {
        let tx = await RillaIndex.functions.makeDaf(
            'TestMultiple',
            dafOwnersAddys
        );
        let receipt = await tx.wait();
        expect(receipt.events[0].event == 'NewDaf');
        daf = await ethers.getContractAt(
            'DAFImplementation',
            RillaIndex.interface.parseLog(receipt.events[0]).args.newDafAddress
        );
        const ownersDAFs: String[] = await RillaIndex.functions.getDAFsForOwner(
            addys[0]
        );
        expect(ownersDAFs.includes(daf.address));
    });

    it('Max 10 owners', async function () {
        await expect(
            RillaIndex.makeDaf('TestMax', [
                ...addys.slice(0, 10),
                usdcRichAdd,
                daiRichAdd,
            ])
        ).to.be.revertedWith('Max 10 owners');
    });

    // donation into daf
    it('Allows donation to DAF of USDC, charges fee', async function () {
        let prevUsdcAmount: BigNumber = await usdc.balanceOf(feeAdd);
        await usdc
            .connect(usdcRich)
            .approve(daf.address, ethers.constants.MaxUint256);
        let donationAmount = BigNumber.from('1000000000');
        let tx = await daf
            .connect(usdcRich)
            .donateToDaf(usdcAdd, donationAmount, '0x');
        await tx.wait();
        let curUsdcAmount: BigNumber = await usdc.balanceOf(feeAdd);
        expect(curUsdcAmount.gt(prevUsdcAmount));
    });
    it('Allows donation to DAF of ETH, charges fee', async function () {
        let prevUsdcAmount: BigNumber = await usdc.balanceOf(feeAdd);

        let donationAmount = ethers.utils.parseEther('1');
        let feeAmount = await feeInCalc(donationAmount);
        let quoteData = await quote0x(wethAdd, feeAmount);
        let tx = await daf
            .connect(accounts[1])
            .donateEthToDaf(quoteData, { value: donationAmount });
        await tx.wait();

        let curUsdcAmount: BigNumber = await usdc.balanceOf(feeAdd);
        expect(curUsdcAmount.gt(prevUsdcAmount));
    });
    it('Allows donation to DAF of DAI, charges fee', async function () {
        let prevUsdcAmount: BigNumber = await usdc.balanceOf(feeAdd);
        let donationAmount = BigNumber.from('1000').mul(
            BigNumber.from('1' + '0'.repeat(18))
        );
        let feeAmount = await feeInCalc(donationAmount);
        let quoteData = await quote0x(daiAdd, feeAmount);
        await dai.connect(daiRich).approve(daf.address, MAXUINT);
        let tx = await daf
            .connect(daiRich)
            .donateToDaf(daiAdd, donationAmount, quoteData);
        await tx.wait();

        let curUsdcAmount: BigNumber = await usdc.balanceOf(feeAdd);
        expect(curUsdcAmount.gt(prevUsdcAmount));
    });

    // donation voting preparation
    it('Frees WETH for donation', async function () {
        let prevUsdcAmount: BigNumber = await usdc.balanceOf(daf.address);
        let wethBal: BigNumber = await weth.balanceOf(daf.address);
        let quoteData = await quote0x(wethAdd, wethBal);
        await expect(
            daf.freeFundsForDonation(wethAdd, wethBal.add(1), quoteData)
        ).to.be.revertedWith('Not enough funds');
        await daf.freeFundsForDonation(wethAdd, wethBal, quoteData);

        let curUsdcAmount: BigNumber = await usdc.balanceOf(daf.address);
        expect(curUsdcAmount.gt(prevUsdcAmount));
        let newWethBal: BigNumber = await weth.balanceOf(daf.address);
        expect(wethBal.gt(newWethBal));
        expect(newWethBal.eq(0));
    });
    it('Frees DAI for donation', async function () {
        let prevUsdcAmount: BigNumber = await usdc.balanceOf(daf.address);
        let daiBal: BigNumber = await dai.balanceOf(daf.address);
        let quoteData = await quote0x(daiAdd, daiBal);
        await expect(
            daf.freeFundsForDonation(daiAdd, daiBal.add(1), quoteData)
        ).to.be.revertedWith('Not enough funds');
        await daf.freeFundsForDonation(daiAdd, daiBal, quoteData);

        let curUsdcAmount: BigNumber = await usdc.balanceOf(daf.address);
        expect(curUsdcAmount.gt(prevUsdcAmount));
        let newDaiBal: BigNumber = await dai.balanceOf(daf.address);
        expect(daiBal.gt(newDaiBal));
        expect(newDaiBal.eq(0));
    });

    it('Only accepted EINs', async function () {
        await expect(daf.createOutDonation(1000, 1)).to.be.revertedWith(
            'Charity not enabled'
        );
    });
    it('Accepts new EINs', async function () {
        await RillaIndex.connect(deployer).modifyCharities(
            [1, 2, 3],
            [true, true, true]
        );
        expect(await RillaIndex.isAcceptedEIN(1));
        expect(await RillaIndex.isAcceptedEIN(2));
        expect(await RillaIndex.isAcceptedEIN(3));
        expect(await RillaIndex.isAcceptedEIN(4)).to.be.false;
        await expect(
            RillaIndex.connect(accounts[1]).modifyCharities([1], [false])
        ).to.be.reverted;
    });
    // donation voting
    it('Can create a vote to send a donation', async function () {
        const donationAmount = 1000;
        await daf.createOutDonation(donationAmount, 1);
        expect((await daf.donations(0)).amount == donationAmount);
    });
    it('Cannot immediately pass a vote', async function () {
        const balance = ethers.utils.parseEther('10000');
        await Promise.all(
            dafOwnersAddys.map((owner) =>
                Rilla.connect(deployer).transfer(
                    owner,
                    balance
                )
            )
        );
        // TODO: Make sure VeRilla is removed completely and tests still work
        await daf.voteOutDonation(0, balance);
        await expect(daf.fulfillDonation(0)).to.be.reverted;
    });
    it('Cannot immediately pass a vote with > 50% voting power', async function () {
        await Promise.all(
            dafOwners.slice(0, 6).map(async (owner) => {
                const balance = await Rilla['balanceOf(address)'](
                    await owner.getAddress()
                );
                return daf
                    .connect(owner)
                    .voteOutDonation(0, balance);
            })
        );
        await expect(daf.fulfillDonation(0)).to.be.revertedWith(
            'Must allow the interim wait time before fulfilling donation'
        );
    });
    it('Can pass a vote with > 50% voting power after 1 day', async function () {
        await time.increase(86401);
        await daf.fulfillDonation(0);
        expect((await daf.donations(0)).fulfilled);
    });
    it('Can pass a vote after 1 week', async function () {
        const amount = 1000;
        await daf.createOutDonation(amount, 2);
        await daf.voteOutDonation(1, ethers.utils.parseEther('9000'));
        await time.increase(86401 * 7);
        await daf.fulfillDonation(1);
        expect((await daf.donations(1)).fulfilled);
        await expect(daf.donations(2)).to.be.reverted;
    });

    // owner voting
    it('Can create a vote to add an owner', async function () {});
    it('Can fail a vote to add an owner', async function () {});
    it('Can pass a vote to add an owner', async function () {});
    it('Can create a vote to remove an owner', async function () {});
    it('Can fail a vote to remove an owner', async function () {});
    it('Can pass a vote to remove an owner', async function () {});
});
