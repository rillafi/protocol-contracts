//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SCLR is ERC20 {
    constructor() ERC20("Sch0lar", "SCLR") {
        _mint(msg.sender, 1_000_000_000 * 10**decimals());
    }
}
