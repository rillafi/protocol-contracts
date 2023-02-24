import { ethers } from 'hardhat';
import { BigNumber } from 'ethers';
import Excel from 'exceljs';
import fs from 'fs';
import path from 'path';

async function main() {
    const workbook = new Excel.Workbook();
    await workbook.xlsx.load(
        fs.readFileSync(path.join(__dirname, './Cap Table.xlsx'))
    );
    const sheet = workbook.getWorksheet('Aaron');
    const addresses = new Set();

    // grab all addresses in array, and an index for each time they appear in that array, and the type of vesting they need
    sheet.eachRow(function(row, rowNumber) {
        if (rowNumber == 1) return;
        if (!row.getCell(4).value?.valueOf()) return;
        addresses.add(row.getCell(4).value?.valueOf() as string);
    });
    let initialAmount = ethers.utils.parseEther('0.001');
    let amount = (
        initialAmount.mod(addresses.size).eq(0)
            ? initialAmount
            : initialAmount
                .add(addresses.size)
                .sub(initialAmount.mod(addresses.size))
    )
        .div(addresses.size)
        .toString();

    let mAddresses = '[';
    let mAmounts = '[';
    for (const entry of addresses.values()) {
        mAddresses += `${entry},\n`;
        mAmounts += `${amount},\n`;
    }

    mAddresses = mAddresses.slice(0, mAddresses.length - 1) + ']';
    mAmounts = mAmounts.slice(0, mAddresses.length - 1) + ']';
    console.log(
        ethers.utils.formatEther(
            ethers.BigNumber.from(amount).mul(addresses.size)
        )
    );
    console.log(mAddresses);
    console.log(mAmounts);
}

main();
