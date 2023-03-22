import { ethers } from 'hardhat';
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
    let initialAmount = ethers.utils.parseEther('0.255');
    let amount = (
        initialAmount.mod(addresses.size).eq(0)
            ? initialAmount
            : initialAmount
                .add(addresses.size)
                .sub(initialAmount.mod(addresses.size))
    )
        .div(addresses.size);

    console.log(await ethers.Wallet.fromMnemonic(process.env.MNEMONIC as string).getAddress());
    const signers = await ethers.getSigners();
    const signer = await ethers.getSigner(await signers[0].getAddress());
    const address = await signer.getAddress();
    console.log(address)
    console.log(await ethers.provider.getBalance(address))
    // console.log(ethers.Wallet.createRandom().privateKey);
    // let lines = '';
    // for (const entry of addresses.values()) {
    //     lines += `${entry},${ethers.utils.formatEther(amount)}\n`
    // }
    // console.log(lines);
    
    // let mAddresses = [];
    // let mAmounts = [];
    // for (const entry of addresses.values()) {
    //     mAddresses.push(`"${entry}"`);
    //     mAmounts.push(amount);
    // }

    // console.log(
    //     ethers.utils.formatEther(
    //         ethers.BigNumber.from(amount).mul(addresses.size)
    //     )
    // );
    //         
    // console.log(ethers.BigNumber.from(amount).mul(addresses.size));
    // console.log(`[${mAddresses.slice(0,50).join(',')}]`);
    // console.log(`[${mAmounts.slice(0,50).join(',')}]`);
    // console.log(mAddresses.length, mAmounts.length);
    let count = 1;
    for (const entry of addresses.values()) {
        if ((await ethers.provider.getBalance(entry as string)).lt(ethers.utils.parseEther('0.00002'))) {
            console.log(`\n\n\n${count}/${addresses.size}`);
            let tx: any = {
                to: entry,
                // Convert currency unit from ether to wei
                value: amount
            };
            const txobj = await signer.sendTransaction(tx);
            await ethers.provider.waitForTransaction(txobj.hash, 1);
            console.log('Sent to ' + entry);
            const newBal = await ethers.provider.getBalance(entry as string) ;
            console.log('New balance is:', ethers.utils.formatEther(newBal));
        }
        ++count;
    }
}

main();
