// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC4626} from "./ERC4626.sol";
import "hardhat/console.sol";

abstract contract RILLAVault is ERC4626, Ownable {
    // ===============================================================
    //                      COMMON BETWEEN VAULTS
    // ===============================================================
    bool public pausedDeposit = false;
    bool public pausedWithdraw = false;
    uint256 depositFeePercent; // MAX VALUE OF 10**6, cannot be greater than feePercent (target 0.5%)
    uint256 feePercent; // MAX VALUE OF 10**6
    address feeAddress;
    address adminAddress;
    uint256 lastHarvest;

    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        uint256 _feePercent,
        address _feeAddress,
        address _adminAddress
    ) ERC4626(ERC20(_asset), _name, _symbol) {
        feePercent = _feePercent;
        feeAddress = _feeAddress;
        adminAddress = _adminAddress;
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

    /// @notice Handles logic related to deposits
    /// @param assets number of assets supplied by the depositor
    /// @param shares number of shares issued by the vault
    function afterDeposit(uint256 assets, uint256 shares)
        internal
        virtual
        override
        pausableDeposit
    {
        ERC20(asset).transfer(feeAddress, (assets * depositFeePercent) / 10**6);
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
    function harvest() public {
        // claim tokens
        handleClaim();
        // charge fees and send donation to admin
        handleFeesAndAdmin();
        // compound that amount
        lastHarvest = block.timestamp;
    }

    function viewBalance(address user) public view returns (uint256) {
        return convertToAssets(balanceOf[user]);
    }

    function getStatsForApy()
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 pendingRewards = viewPendingRewards();
        uint256 timeSince = block.timestamp - lastHarvest;
        return (totalAssets(), asset.decimals(), pendingRewards, timeSince);
    }

    // apy is this:
    // percent = $pendingRewards/(totalAssets()/asset.decimals())
    // annualizedApr = percent*365*24*60*60/timeSince

    // ===============================================================
    //                      VAULT SPECIFIC LOGIC
    // ===============================================================

    function handleWithdrawal(uint256 assets, uint256 shares) internal virtual;

    function handleDeposit(uint256 assets, uint256 shares) internal virtual;

    function handleClaim() internal virtual;

    function handleFeesAndAdmin() internal virtual;

    function viewPendingRewards() internal view virtual returns (uint256);

    // function totalAssets()
}
