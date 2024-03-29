// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RILLA is ERC20 {
    constructor() ERC20("Rilla", "RILLA") {
        _mint(msg.sender, 1_000_000_000 * 10**decimals());
    }
}
