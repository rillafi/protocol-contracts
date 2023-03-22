import { ethers } from 'hardhat';
import { BigNumber } from 'ethers';
import Excel from 'exceljs';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import tokenVestingAbi from '../artifacts/contracts/vesting/TokenVesting.sol/TokenVesting.json';
import erc20Abi from '../artifacts/contracts/token/RILLA.sol/RILLA.json';
import ethProvider from 'eth-provider';

async function main() {
    dotenv.config();
    const YEAR = 365 * 86400;
    const vestType = {
        Team: { tge: 5, duration: 4 * YEAR },
        Advisors: { tge: 5, duration: 3 * YEAR },
        Liquidity: { tge: 100, duration: 0 },
        Endowment: { tge: 20, duration: 2 * YEAR },
        Rewards: { tge: 10, duration: 3 * YEAR },
        Seed: { tge: 5, duration: 2 * YEAR },
        Treasury: { tge: 50, duration: Math.floor(1.5 * YEAR) },
    };
    const workbook = new Excel.Workbook();
    await workbook.xlsx.load(
        fs.readFileSync(path.join(__dirname, './Cap Table.xlsx'))
    );
    const sheet = workbook.getWorksheet('Aaron');
    const vests: {
        vestingType: 'Team' | 'Advisors' | 'Seed';
        name: string;
        amount: BigNumber;
        address: string;
        index: number;
        initialized: boolean;
        row: number;
    }[] = [];

    // grab all addresses in array, and an index for each time they appear in that array, and the type of vesting they need
    sheet.eachRow(function (row, rowNumber) {
        if (rowNumber == 1) return;
        if (!row.getCell(4).value?.valueOf()) return;
        console.log(rowNumber);
        vests.push({
            vestingType: row.getCell(1).value?.valueOf() as
                | 'Team'
                | 'Advisors'
                | 'Seed',
            name: row.getCell(2).value?.valueOf() as string,
            amount: ethers.utils.parseUnits(
                row.getCell(3).toString().replace(',', ''),
                18
            ),
            address: row.getCell(4).value?.valueOf() as string,
            index: vests.filter(
                (vest) =>
                    vest.address == (row.getCell(4).value?.valueOf() as string)
            ).length,
            initialized: false,
            row: rowNumber,
        });
    });

    // init TokenVesting contract
    const startTime = 1676887200;
    console.log(date(startTime));
    const frame = ethProvider('frame'); // Connect to Frame
    const rilla = '0x96D17e1301b31556e5e263389583A9331e6749E9';
    const tokenVesting =
        '0x18894535bE1A02f091B1EaeE8A987DC39Ba4899c' as `0x${string}`;
    const TokenVesting = await ethers.getContractAt(
        tokenVestingAbi.abi,
        tokenVesting
    );
    const Rilla = await ethers.getContractAt(erc20Abi.abi, rilla);
    if (!(await Rilla.balanceOf(TokenVesting.address)).gt(0)) {
        let tx = await Rilla.populateTransaction.transfer(
            tokenVesting,
            ethers.utils.parseEther('1')
        );
        tx.from = (
            (await frame.request({ method: 'eth_requestAccounts' })) as any
        )[0];
        await frame.request({ method: 'eth_sendTransaction', params: [tx] });
        tx = await Rilla.populateTransaction.transfer(
            tokenVesting,
            ethers.utils.parseEther('600000000')
        );
        tx.from = (
            (await frame.request({ method: 'eth_requestAccounts' })) as any
        )[0];
        await frame.request({ method: 'eth_sendTransaction', params: [tx] });
    } else {
        console.log(
            'TokenVesting balance: ',
            Number(
                ethers.utils.formatEther(
                    await TokenVesting.getWithdrawableAmount()
                )
            ).toLocaleString()
        );
    }

    let skipRows = 96;
    // MAKE VESTS
    for (let i = skipRows; i < vests.length; i++) {
        const vest = vests[i];
        const vestData = await TokenVesting.getVestingScheduleByAddressAndIndex(
            vest.address,
            vest.index
        );
        if (vestData.initialized) {
            if (vestData.cliff > Date.now() / 1000 && !vestData.revoked) {
                const id =
                    await TokenVesting.computeVestingScheduleIdForAddressAndIndex(
                        vest.address,
                        vest.index
                    );
                console.log(
                    `\n\nREVOKE ${vest.row} Name: ${vest.name} Address: ${
                        vest.address
                    }, index: ${
                        vest.index
                    }, \nid: ${id.toString()}, cliffdate: ${date(
                        vestData.cliff
                    )}\n\n`
                );
                const res = await TokenVesting.revoke(id);
                await ethers.provider.waitForTransaction(res.hash as string, 1);
            } else if (vest.row <= 109) {
                continue;
            } else if (vestData.revoked) {
            } else {
                continue;
            }
        }
        const type = vestType[vest.vestingType];
        const endTime = startTime + type.duration;
        const duration = Math.floor(type.duration / (1 - type.tge / 100));
        const time = Math.floor(endTime - duration);
        /* const cliff = Math.floor(Date.now() / 1000) + 86400 * 2 - time; // 2 days after startTime */
        const cliff = 0; // 2 days after startTime
        console.log(
            '\n\n',
            'ADD VEST',
            vest.row,
            'Name:',
            vest.name,
            'Amount:',
            Number(ethers.utils.formatEther(vest.amount)).toLocaleString(),
            'End Date:',
            date(endTime),
            '\n',
            'Start time:',
            date(time),
            'Cliff valid:',
            date(time + cliff),
            '\n\n'
        );
        const res = await TokenVesting.createVestingSchedule(
            vest.address,
            time,
            cliff,
            duration,
            1,
            true,
            vest.amount
        );
        /* tx.from = ( */
        /*     (await frame.request({ method: 'eth_requestAccounts' })) as any */
        /* )[0]; */
        /* const res = await frame.request({ */
        /*     method: 'eth_sendTransaction', */
        /*     params: [tx], */
        /* }); */
        await ethers.provider.waitForTransaction(res.hash as string, 1);
        console.log(
            'TokenVesting balance: ',
            Number(
                ethers.utils.formatEther(
                    await TokenVesting.getWithdrawableAmount()
                )
            ).toLocaleString()
        );
    }
}

main();

function date(time: number) {
    var date = new Date(time * 1000);
    return date.toUTCString();
}
