// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IVelodromeGauge {
    function depositAll(uint256 tokenId) external;

    function deposit(uint256, uint256) external;

    function getReward(address account, address[] memory tokens) external;

    function withdraw(uint256 amount) external;

    function earned(address token, address account)
        external
        view
        returns (uint256);

    function balanceOf(address user) external view returns (uint256);
}
