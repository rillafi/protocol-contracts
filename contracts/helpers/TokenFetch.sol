// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IERC20 {
    function balanceOf(address user) external view returns (uint256);

    function decimals() external view returns (uint8);
}

contract TokenFetch {
    function fetchBalances(address user, IERC20[] calldata tokens)
        public
        view
        returns (uint256[] memory, uint256[] memory)
    {
        uint256[] memory balances = new uint256[](tokens.length);
        uint256[] memory decimals = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            balances[i] = tokens[i].balanceOf(user);
            decimals[i] = uint256(tokens[i].decimals());
        }
        return (balances, decimals);
    }
}
