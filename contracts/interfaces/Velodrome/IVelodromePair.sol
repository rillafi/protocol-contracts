// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IVelodromePair {
    function token0() external returns (address);

    function stable() external returns (bool);

    function allowance(address owner, address spender)
        external
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
}
