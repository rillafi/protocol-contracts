// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SCLR is ERC20 {
    constructor() ERC20("Sch0lar", "SCLR") {
        _mint(msg.sender, 1000000000 * 10**decimals());
    }
}
