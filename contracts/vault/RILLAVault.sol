// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC4626} from "./ERC4626.sol";

abstract contract RILLAVault is ERC4626, Ownable {
    // ===============================================================
    //                      COMMON BETWEEN VAULTS
    // ===============================================================
    bool public pausedDeposit = false;
    bool public pausedWithdraw = false;
    address yieldSource;
    uint256 depositFeePercent; // MAX VALUE OF 10**6, cannot be greater than feePercent (target 0.5%)
    uint256 feePercent; // MAX VALUE OF 10**6
    address feeAddress;
    address adminAddress;
    uint256 lastCompound;

    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        address _yieldSource,
        uint256 _feePercent,
        address _feeAddress,
        address _adminAddress
    ) ERC4626(ERC20(_asset), _name, _symbol) {
        yieldSource = _yieldSource;
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
        ERC20(asset).transfer(
            feeAddress,
            (assets * depositFeePercent) / 10**18
        );
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
        handleClaim(compoundAmount, pendingAssets);
        // charge fees and send donation to admin
        handleFeesAndAdmin();
        // compound that amount
        // handleCompound();

        // uint256 effectiveAdminPercent = 10**18 -
        //     feePercent +
        //     ((10**18 - feePercent) * depositFeePercent) /
        //     10**18;
        // uint256 assetsToAdmin = (pendingAssets * effectiveAdminPercent) /
        //     10**18;
        // mint proper amount of shares to the admin account (for scholarships)
        // deposit(assetsToAdmin, adminAddress);
        // mint proper amount of shares to the fee account (15% or so of total pendingAssets)
        // deposit(pendingAssets - assetsToAdmin, feeAddress);

        lastCompound = block.timestamp;
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
        uint256 pendingRewards = viewPendingRewardAssets();
        uint256 timeSince = block.timestamp - lastCompound;
        return (totalAssets(), asset.decimals(), pendingRewards, timeSince);
    }

    // apy is this:
    // percent = pendingRewards/(totalAssets()/asset.decimals())
    // annualizedApr = percent*365*24*60*60/timeSince

    // ===============================================================
    //                      VAULT SPECIFIC LOGIC
    // ===============================================================

    function handleWithdrawal(uint256 assets, uint256 shares)
        internal
        virtual
    {}

    function handleDeposit(uint256 assets, uint256 shares) internal virtual {}

    function handleClaim(uint256 claimAmount, uint256 pendingAssets)
        internal
        virtual
    {}

    function handleFeesAndAdmin() internal virtual {}

    function handleCompound() internal virtual {}

    function viewPendingRewards() internal view virtual returns (uint256) {}

    function viewPendingRewardAssets()
        internal
        view
        virtual
        returns (uint256)
    {}

    // function totalAssets()
}
