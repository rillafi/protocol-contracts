// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
}

contract TokenFetch {
    function fetchBalances(address owner, IERC20[] calldata tokens)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory balances = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            balances[i] = tokens[i].balanceOf(owner);
        }
        return (balances);
    }

    function fetchAllowances(
        address owner,
        address spender,
        IERC20[] calldata tokens
    ) public view returns (uint256[] memory) {
        uint256[] memory allowances = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            allowances[i] = tokens[i].allowance(spender, owner);
        }
        return (allowances);
    }
}
