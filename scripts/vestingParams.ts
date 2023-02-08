import { BigNumber } from 'ethers';
function main() {
    const decimals = 18;

    const YEAR = 86400 * 365;
    const SIXMONTHS = 86400 * 30 * 6;

    /* function createVestingSchedule( */
    /*     address _beneficiary, */
    /*     uint256 _start, */
    /*     uint256 _cliff, */
    /*     uint256 _duration, */
    /*     uint256 _slicePeriodSeconds, */
    /*     bool _revocable, */
    /*     uint256 _amount */
    /* ) */

    const address = '0x5117438e943ab870625dda4B0FE3b8118640fFdb';
    const start = 1675443600;
    const cliff = 0;
    const duration = YEAR;
    const slice = 1;
    const revocable = true;
    let amount: number | BigNumber = 21_000_000;
    amount = BigNumber.from(`${amount}` + '0'.repeat(decimals));
    console.log('address: ', address);
    console.log('start: ', start);
    console.log('cliff: ', cliff);
    console.log('duration: ', duration);
    console.log('slice: ', slice);
    console.log('revocable: ', revocable);
    console.log('amount: ', BigNumber.from(amount).toString());

    // read csv amount and addresses
    // read tokenvesting contract and see if address has vesting already with amount
    // if not, create vesting with params based on role and amount
}

main();
