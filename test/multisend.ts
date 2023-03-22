import { ethers } from 'hardhat';
import { Contract } from 'ethers';
import Excel from 'exceljs';
import fs from 'fs';
import path from 'path';

describe('DAF', function () {
    let multisendAddress = "0x2C5e535c6Ac996B357fFdb7AaD48a0bF65aac3F8";
    let multisend: Contract;

    before(async function () {
        console.log('1');
        multisend = await ethers.getContractAt('Multisend', multisendAddress);
        console.log(multisend.functions)
        console.log('2');
    });

    it('Sends multiple eth to anyone', async function () {
        const workbook = new Excel.Workbook();
        await workbook.xlsx.load(
            fs.readFileSync(path.join(__dirname, '../scripts/Cap Table.xlsx'))
        );
        const sheet = workbook.getWorksheet('Aaron');
        const addresses = new Set();

        // grab all addresses in array, and an index for each time they appear in that array, and the type of vesting they need
        sheet.eachRow(function(row, rowNumber) {
            if (rowNumber == 1) return;
            if (!row.getCell(4).value?.valueOf()) return;
            addresses.add(row.getCell(4).value?.valueOf() as string);
        });
        let initialAmount = ethers.utils.parseEther('0.0001');
        let amount = (
            initialAmount.mod(addresses.size).eq(0)
                ? initialAmount
                : initialAmount
                .add(addresses.size)
                .sub(initialAmount.mod(addresses.size))
        )
        .div(addresses.size)
        .toString();

        let mAddresses = [];
        let mAmounts = [];
        for (const entry of addresses.values()) {
            if (!ethers.utils.isAddress(entry as string)) {
                console.log('uhoh');
            }
            mAddresses.push(`${entry}`);
            mAmounts.push(amount);
        }

        console.log(
            ethers.utils.formatEther(
                ethers.BigNumber.from(amount).mul(addresses.size)
            )
        );

        const value = ethers.BigNumber.from(amount).mul(addresses.size).toString();
        const addressOut = `[${mAddresses.join(',')}]`;
        const amountOut = `[${mAmounts.join(',')}]`;
        console.log(value);
        console.log(addressOut);
        console.log(amountOut);
        await multisend.multisendEth(mAddresses, mAmounts, { value })
    });
});
