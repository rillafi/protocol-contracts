// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC4626} from "./ERC4626.sol";

abstract contract SCLRVault is ERC4626, Ownable {
    // ===============================================================
    //                      COMMON BETWEEN VAULTS
    // ===============================================================
    address yieldSource;
    bool public pausedDeposit = false;
    bool public pausedWithdraw = false;

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _yieldSource
    ) ERC4626(_asset, _name, _symbol) {
        yieldSource = _yieldSource;
    }

    modifier pausableDeposit() {
        require(!pausedDeposit, "Deposits are paused");
        _;
    }

    modifier pausableWithdrawal() {
        require(!pausedWithdraw, "Withdrawals are paused");
        _;
    }

    function toggleDepositPause() public onlyOwner {
        pausedDeposit = !pausedDeposit;
    }

    function toggleWithdrawalPause() public onlyOwner {
        pausedWithdraw = !pausedWithdraw;
    }

    // NONTRANSFERRABLE TOKEN
    function transfer(address to, uint256 amount)
        public
        pure
        override
        returns (bool)
    {
        revert();
    }

    // NONTRANSFERRABLE TOKEN
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public pure override returns (bool) {
        revert();
    }

    /// @notice Approve the transfer of tokens for our yield partner's contract
    /// @param amount number of assets supplied by the depositor
    function approveYieldSource(uint256 amount) public onlyOwner {
        asset.approve(yieldSource, amount);
    }

    /// @notice Handles logic related to deposits
    /// @param assets number of assets supplied by the depositor
    /// @param shares number of shares issued by the vault
    function afterDeposit(uint256 assets, uint256 shares)
        internal
        virtual
        override
        pausableDeposit
    {
        // call deposit on the yieldpartner contract
        handleDeposit(assets, shares);
    }

    /// @notice Handles logic related to withdrawals
    /// @param assets number of assets supplied by the depositor
    /// @param shares number of shares issued by the vault
    function beforeWithdraw(uint256 assets, uint256 shares)
        internal
        virtual
        override
        pausableWithdrawal
    {
        // call withdraw on the yieldpartner contract
        handleWithdrawal(assets, shares);
    }

    /// @notice Handles logic related to compounding deposits
    /// @dev Compounds are minted to the admin account, as yield is returned to that account
    function compound() public {
        // view amount to be autocompounded
        uint256 compoundAmount = viewPendingRewards();
        // convert to shares
        uint256 pendingAssets = viewPendingRewardAssets();
        // claim that amount
        handleCompound(compoundAmount, pendingAssets);
        // deposit that amount
        // mint proper amount of shares to the fee account (15% or so of total pendingAssets)
        // mint proper amount of shares to the admin account
    }

    function viewBalance(address user) public view returns (uint256) {
        return convertToAssets(balanceOf[user]);
    }

    // ===============================================================
    //                      VAULT SPECIFIC LOGIC
    // ===============================================================

    function handleWithdrawal(uint256 assets, uint256 shares)
        internal
        virtual
    {}

    function handleDeposit(uint256 assets, uint256 shares) internal virtual {}

    function handleCompound(uint256 compoundAmount, uint256 pendingAssets)
        internal
        virtual
    {}

    function viewPendingRewards() internal virtual returns (uint256) {}

    function viewPendingRewardAssets() internal virtual returns (uint256) {}
}
