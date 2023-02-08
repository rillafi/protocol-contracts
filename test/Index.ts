import fetch from 'node-fetch';
import hre, { ethers, upgrades } from 'hardhat';
import { Signer, Contract, BigNumber, BigNumberish } from 'ethers';
import { expect } from 'chai';
import erc20abi from '../abis/erc20abi.json';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { parseUnits } from 'ethers/lib/utils';
import { days } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time/duration';

enum VoteType {
    DONATION = 0,
    OWNERCHANGE = 1,
    SWAP = 2,
}
describe('DAF', function () {
    const MAXTIME = 2 * 365 * 86400;

    let dai: Contract;
    let usdc: Contract;
    let weth: Contract;
    let DafImplementation: Contract;
    let RillaIndex: Contract;
    let RillaIndexImpl: Contract;
    let Rilla: Contract;
    /* let VeRilla: Contract; */
    let accounts: Signer[];
    let addys: String[];
    let deployer: Signer;
    let user: Signer;
    let userAdd: String;
    let feeAcc: Signer;
    let feeAdd: String;
    let treasury: Signer;
    let treasuryAdd: String;
    let depositor: Signer;
    let depAdd: String;
    let daf: Contract;
    let usdcRichAdd: string = '0xEbe80f029b1c02862B9E8a70a7e5317C06F62Cae';
    let usdcRich: Signer;
    let daiRichAdd: string = '0xc66825C5c04b3c2CcD536d626934E16248A63f68';
    let daiRich: Signer;
    let dafOwnersAddys: String[];
    let dafOwners: Signer[];

    const wethAdd = '0x4200000000000000000000000000000000000006';
    const usdcAdd = '0x7f5c764cbc14f9669b88837ca1490cca17c31607';
    const daiAdd = '0xda10009cbd5d07dd0cecc66161fc93d7c9000da1';
    const MAXUINT = ethers.constants.MaxUint256;

    async function quote0x(from: string, to: string, amount: BigNumber) {
        let searchParams = new URLSearchParams({
            sellToken: from,
            buyToken: to,
            sellAmount: amount.toString(),
        });
        let res = await fetch(
            `https://optimism.api.0x.org/swap/v1/quote?${searchParams.toString()}`
        );
        return (await res.json()).data;
    }

    async function feeInCalc(amount: BigNumberish) {
        let fee: BigNumber = await RillaIndex.feeInBps();
        return fee.mul(amount).div('10000');
    }
    async function tradeToUsdc(
        daf: Contract,
        sender: Signer,
        token: string,
        amount: BigNumberish
    ) {
        await daf.connect(sender).createSwap(token, usdcAdd, amount);
        const id = (await daf.getSwapsLength()) - 1;
        await time.increase(days(2));
        await Promise.all(
            dafOwners.map((owner) =>
                daf
                    .connect(owner)
                    .dafVote(id, parseUnits('10000', 18), VoteType.SWAP)
            )
        );
        const swap = quote0x(token, usdcAdd, await feeInCalc(amount));
        const feeSwap = quote0x(token, usdcAdd, await feeInCalc(amount));
        await daf.connect(sender).fulfillSwap(id, swap, feeSwap);
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
        treasury = accounts[11];
        treasuryAdd = addys[11];
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
        dafOwners = [...accounts.slice(0, 6), usdcRich, daiRich];
        dafOwnersAddys = [...addys.slice(0, 6), usdcRichAdd, daiRichAdd];

        // Deploy Contracts
        let rilla = await ethers.getContractFactory('RILLA', deployer);
        Rilla = await rilla.deploy();

        await Rilla.transfer(
            treasuryAdd,
            BigNumber.from('500000000' + '0'.repeat(18))
        );

        let dafImplementation = await ethers.getContractFactory(
            'DAFImplementation',
            deployer
        );
        DafImplementation = await dafImplementation.deploy();

        let rillaIndexImpl = await ethers.getContractFactory(
            'RillaIndex',
            deployer
        );
        RillaIndexImpl = await rillaIndexImpl.deploy();
        RillaIndex = await upgrades.deployProxy(rillaIndexImpl, [
            DafImplementation.address,
            Rilla.address,
            feeAdd,
            treasuryAdd,
            BigNumber.from(1e10), // 1 cent swap rate
        ]);

        await Rilla.connect(treasury).approve(
            RillaIndex.address,
            ethers.constants.MaxUint256
        );
        const balance = parseUnits('10000', 18);
        await Promise.all(
            dafOwnersAddys.map((owner) =>
                Rilla.connect(deployer).transfer(owner, balance)
            )
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
        expect(ownersDAFs[0] == daf.address);
    });

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
        let donationAmount = parseUnits('1000', 6);
        let tx = await daf
            .connect(usdcRich)
            .donateToDaf(usdcAdd, donationAmount, '0x');
        await tx.wait();
        let curUsdcAmount: BigNumber = await usdc.balanceOf(feeAdd);
        expect(curUsdcAmount.gt(prevUsdcAmount));
    });
    it('Allows donation to DAF of ETH, charges fee', async function () {
        let prevUsdcAmount: BigNumber = await usdc.balanceOf(feeAdd);

        let donationAmount = ethers.utils.parseEther('625');
        let feeAmount = await feeInCalc(donationAmount);
        let quoteData = await quote0x(wethAdd, usdcAdd, feeAmount);
        let tx = await daf
            .connect(accounts[1])
            .donateEthToDaf(quoteData, { value: donationAmount });
        await tx.wait();

        let curUsdcAmount: BigNumber = await usdc.balanceOf(feeAdd);
        expect(curUsdcAmount.gt(prevUsdcAmount));
    });
    // donation voting preparation
    it('Frees WETH for donation', async function () {
        let prevUsdcAmount: BigNumber = await usdc.balanceOf(daf.address);
        let wethBal: BigNumber = await weth.balanceOf(daf.address);
        await tradeToUsdc(daf, dafOwners[0], wethAdd, wethBal);

        let curUsdcAmount: BigNumber = await usdc.balanceOf(daf.address);
        expect(curUsdcAmount.gt(prevUsdcAmount));
        let newWethBal: BigNumber = await weth.balanceOf(daf.address);
        expect(wethBal.gt(newWethBal));
        expect(newWethBal.eq(0));
    });
    it('Awards RILLA for donation', async function () {
        let prev = await Rilla.balanceOf(usdcRichAdd);
        let donationAmount = parseUnits('1000', 6);
        await daf.connect(usdcRich).donateToDaf(usdcAdd, donationAmount, '0x');
        let cur = await Rilla.balanceOf(usdcRichAdd);
        expect(cur.gt(prev));
        prev = await Rilla.balanceOf(daiRichAdd);
        donationAmount = parseUnits('1000', 18);
        let feeAmount = await feeInCalc(donationAmount);
        let quote = quote0x(daiAdd, usdcAdd, feeAmount);
        await dai.connect(daiRich).approve(daf.address, MAXUINT);
        await daf.connect(daiRich).donateToDaf(daiAdd, donationAmount, quote);
        cur = await Rilla.balanceOf(daiRichAdd);
        expect(cur.gt(prev));

        prev = await Rilla.balanceOf(daiRichAdd);
        donationAmount = ethers.utils.parseEther('625');
        feeAmount = await feeInCalc(donationAmount);
        let quoteData = await quote0x(wethAdd, usdcAdd, feeAmount);
        let tx = await daf
            .connect(accounts[1])
            .donateEthToDaf(quoteData, { value: donationAmount });
        await tx.wait();

        cur = await Rilla.balanceOf(daiRichAdd);
        expect(cur.gt(prev));
    });
    it('Allows donation to DAF of DAI, charges fee', async function () {
        let prevUsdcAmount: BigNumber = await usdc.balanceOf(feeAdd);
        let donationAmount = BigNumber.from('1000').mul(
            BigNumber.from('1' + '0'.repeat(18))
        );
        let feeAmount = await feeInCalc(donationAmount);
        let quoteData = await quote0x(daiAdd, usdcAdd, feeAmount);
        await dai.connect(daiRich).approve(daf.address, MAXUINT);
        let tx = await daf
            .connect(daiRich)
            .donateToDaf(daiAdd, donationAmount, quoteData);
        await tx.wait();

        let curUsdcAmount: BigNumber = await usdc.balanceOf(feeAdd);
        expect(curUsdcAmount.gt(prevUsdcAmount));
    });

    it('Frees DAI for donation', async function () {
        let prevUsdcAmount: BigNumber = await usdc.balanceOf(daf.address);
        let daiBal: BigNumber = await dai.balanceOf(daf.address);
        await tradeToUsdc(daf, dafOwners[0], daiAdd, daiBal);

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
        // TODO: Make sure VeRilla is removed completely and tests still work
        await daf.dafVote(0, balance, VoteType.DONATION);
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
                    .dafVote(0, balance, VoteType.DONATION);
            })
        );
        await expect(daf.fulfillDonation(0)).to.be.revertedWith(
            'Must allow the interim wait time before fulfilling vote'
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
        await daf.dafVote(
            1,
            ethers.utils.parseUnits('10000', 18),
            VoteType.DONATION
        );
        await time.increase(86401 * 7);
        await daf.fulfillDonation(1);
        expect((await daf.donations(1)).fulfilled);
        await expect(daf.donations(2)).to.be.reverted;
    });

    // owner voting
    it('Can create a vote to add an owner', async function () {
        await daf.connect(dafOwners[0]).createOwnerChange([treasuryAdd], true);
        const valid = await daf.ownerChanges(0);
        expect(valid);
        await expect(daf.ownerChanges(1)).to.be.reverted;
    });
    it('Can fail a vote to add an owner', async function () {
        await time.increase(days(2));
        await Promise.all(
            dafOwners
                .slice(0, 5)
                .map((owner) =>
                    daf
                        .connect(owner)
                        .dafVote(
                            0,
                            '-' + parseUnits('10000', 18).toString(),
                            VoteType.OWNERCHANGE
                        )
                )
        );
        await expect(daf.connect(dafOwners[0]).fulfillOwnerChange(0)).to.be
            .reverted;
    });
    it('Can pass a vote to add an owner', async function () {
        await daf.connect(dafOwners[0]).createOwnerChange([feeAdd], true);
        await Promise.all(
            dafOwners
                .slice(0, 5)
                .map((owner) =>
                    daf
                        .connect(owner)
                        .dafVote(
                            1,
                            parseUnits('10000', 18).toString(),
                            VoteType.OWNERCHANGE
                        )
                )
        );
        await time.increase(days(2));
        expect(await daf.connect(dafOwners[0]).fulfillOwnerChange(1));
        expect(await daf.getOwners()).to.include(feeAdd);
    });
    it('Can create a vote to remove an owner', async function () {
        await daf.connect(dafOwners[0]).createOwnerChange([feeAdd], false);
        await Promise.all(
            dafOwners
                .slice(0, 5)
                .map((owner) =>
                    daf
                        .connect(owner)
                        .dafVote(
                            2,
                            parseUnits('10000', 18).toString(),
                            VoteType.OWNERCHANGE
                        )
                )
        );
    });
    it('Can fail a vote to remove an owner', async function () {
        await time.increase(days(2));
        await Promise.all(
            dafOwners
                .slice(0, 5)
                .map((owner) =>
                    daf
                        .connect(owner)
                        .dafVote(
                            2,
                            '-' + parseUnits('10000', 18).toString(),
                            VoteType.OWNERCHANGE
                        )
                )
        );
        await expect(daf.connect(dafOwners[2]).fulfillOwnerChange(2)).to.be
            .reverted;
        expect(await daf.getOwners()).to.include(feeAdd);
    });
    it('Can pass a vote to remove an owner', async function () {
        await daf.connect(dafOwners[0]).createOwnerChange([feeAdd], false);
        await time.increase(days(2));
        await Promise.all(
            dafOwners
                .slice(0, 5)
                .map((owner) =>
                    daf
                        .connect(owner)
                        .dafVote(
                            3,
                            parseUnits('10000', 18).toString(),
                            VoteType.OWNERCHANGE
                        )
                )
        );
        expect(await daf.connect(dafOwners[2]).fulfillOwnerChange(3));
        expect(await daf.getOwners()).to.not.include(feeAdd);
    });
    it('Fetches Active Swaps', async function () {
        await daf
            .connect(dafOwners[0])
            .createSwap(wethAdd, daiAdd, parseUnits('1', 18));
        let swaps = await daf.fetchActiveSwaps();
        expect(swaps);
        await Promise.all(
            new Array(55)
                .fill(0)
                .map(() =>
                    daf
                        .connect(dafOwners[0])
                        .createSwap(wethAdd, daiAdd, parseUnits('1', 18))
                )
        );
        swaps = await daf.fetchActiveSwaps();
        expect(swaps);
    });

    it('Fetches Active Donations', async function () {
        await daf.createOutDonation(1000, 1);
        let donations = await daf.fetchActiveDonations();
        expect(donations);
        await Promise.all(
            new Array(55).fill(0).map(() => daf.createOutDonation(1000, 1))
        );
        donations = await daf.fetchActiveDonations();
        expect(donations);
    });

    it('Fetches Active Owners', async function () {
        await daf.createOwnerChange([treasuryAdd], true);
        let ownerChanges = await daf.fetchActiveOwnerChanges();
        expect(ownerChanges);
        await Promise.all(
            new Array(55)
                .fill(0)
                .map(() => daf.createOwnerChange([treasuryAdd], true))
        );
        ownerChanges = await daf.fetchActiveOwnerChanges();
        expect(ownerChanges);
        // returns all, including array elements which are just the 0 values. must account for this in our frontend
    });

    // TODO: MORE TESTING for index
    it('gets donation', async function () {
        const second = await RillaIndex.donations(0);
        expect(second);
    });
    it('gets unfulfilled donations', async function () {
        const nDonations = await RillaIndex.nDonations();
        const first = await RillaIndex.getUnfulfilledDonations();
        // TODO: Make a ton of donations (1000) and then try it
        /* const donOuts = await Promise.all( */
        /*     new Array(100).fill(0).map((elem) => daf.createOutDonation(1, 1)) */
        /* ); */
        /* await time.increase(days(2)); */
        /* await Promise.all( */
        /*     dafOwners */
        /*         .slice(0, 5) */
        /*         .map((owner) => */
        /*             donOuts.map((_, i) => */
        /*                 daf */
        /*                     .connect(owner) */
        /*                     .dafVote( */
        /*                         nDonations.add(i), */
        /*                         parseUnits('10000', 18), */
        /*                         VoteType.DONATION */
        /*                     ) */
        /*             ) */
        /*         ) */
        /* ); */
        /* await Promise.all( */
        /*     donOuts.map((_, i) => */
        /*         daf.connect(dafOwners[0]).fulfillDonation(nDonations.add(i)) */
        /*     ) */
        /* ); */
        /* const second = await RillaIndex.getUnfulfilledDonations(); */
        /* console.log(first, second); */
        /* console.log('numUnfulfilled: ', await RillaIndex.numUnfulfilled()) */
    });
    it('modifies multiple charities at once', async function () {
        const eins = [10, 20, 30, 1];
        const bools = [true, true, true, false];
        await RillaIndex.modifyCharities(eins, bools);
        const vals = await Promise.all(
            eins.map((ein) => RillaIndex.charities(ein))
        );
        vals.forEach((v, i) => expect(v).to.equal(bools[i]));
    });
    it('Fulfills Donations', async function () {
        const prev = await RillaIndex.numUnfulfilled();
        const [_, ids] = await RillaIndex.getUnfulfilledDonations();
        await expect(RillaIndex.connect(accounts[10]).fulfillDonations(ids)).to
            .be.reverted;
        await RillaIndex.fulfillDonations(ids);
        const cur = await RillaIndex.numUnfulfilled();
        expect(cur.gt(prev));
    });
    it('Gets DAFs for Owner', async function () {
        const dafs: any[] = await RillaIndex.getDAFsForOwner(addys[0]);
        expect(dafs).includes(daf.address);
    });
    it('All setters work', async function () {
        await RillaIndex.setDafImplementation(addys[1]);
        let val = await RillaIndex.dafImplementation();
        expect(val).to.equal(addys[1]);
        await RillaIndex.setRilla(addys[1]);
        val = await RillaIndex.rilla();
        expect(val).to.equal(addys[1]);
        await RillaIndex.setRillaSwapRate('1');
        val = await RillaIndex.rillaSwapRate();
        expect(val.eq('1'));
        await RillaIndex.setRillaSwapLive(false);
        val = await RillaIndex.isRillaSwapLive();
        expect(val).to.equal(false);
        await RillaIndex.setTreasury(addys[1]);
        val = await RillaIndex.treasury();
        expect(val).to.equal(addys[1]);
        await RillaIndex.setFeeAddress(addys[1]);
        val = await RillaIndex.feeAddress();
        expect(val).to.equal(addys[1]);
        await RillaIndex.setFeeOutBps(1000);
        val = await RillaIndex.feeOutBps();
        expect(val.eq(1000));
        await RillaIndex.setFeeInBps(1000);
        val = await RillaIndex.feeInBps();
        expect(val.eq(1000));
        await RillaIndex.setFeeSwapBps(1000);
        val = await RillaIndex.feeSwapBps();
        expect(val.eq(1000));
        await RillaIndex.setWaitTime(1000);
        val = await RillaIndex.waitTime();
        expect(val.eq(1000));
        await RillaIndex.setInterimWaitTime(1000);
        val = await RillaIndex.interimWaitTime();
        expect(val.eq(1000));
        await RillaIndex.setExpireTime(1000);
        val = await RillaIndex.expireTime();
        expect(val.eq(1000));
        await RillaIndex.setRillaVoteMin(1000);
        val = await RillaIndex.rillaVoteMin();
        expect(val.eq(1000));
    });
    // TODO: think about upgradeability
    // TODO: think about pauseability for fulfills (swapRilla function will need to do a swap through 0x)
    // TODO: think about upgrading DAF to new swap mechanics
});
