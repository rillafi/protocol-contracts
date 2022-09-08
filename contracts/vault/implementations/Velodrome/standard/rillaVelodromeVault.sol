// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {RILLAVault} from "../../../RILLAVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "hardhat/console.sol";
import {IVelodromeRouter} from "../../../../interfaces/Velodrome/IVelodromeRouter.sol";
import {IVelodromePair} from "../../../../interfaces/Velodrome/IVelodromePair.sol";
import {IVelodromeGauge} from "../../../../interfaces/Velodrome/IVelodromeGauge.sol";

contract rillaVelodromeVault is RILLAVault {
    IVelodromeGauge veloGauge;
    IVelodromePair veloPair;
    address token0;
    address token1;
    address rewardToken;
    address feeCollectionToken;
    IVelodromeRouter public immutable veloRouter =
        IVelodromeRouter(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);
    IVelodromeRouter.route[] public routeRewardToken;

    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        uint256 _feePercent,
        address _feeAddress,
        address _adminAddress,
        address _veloGauge,
        address _rewardToken,
        IVelodromeRouter.route[] memory _routeRewardToken
    )
        RILLAVault(
            _asset,
            _name,
            _symbol,
            _feePercent,
            _feeAddress,
            _adminAddress
        )
    {
        veloGauge = IVelodromeGauge(_veloGauge);
        veloPair = IVelodromePair(_asset);
        rewardToken = _rewardToken;
        for (uint256 i = 0; i < _routeRewardToken.length; i++) {
            routeRewardToken.push(_routeRewardToken[i]);
        }
    }

    function handleWithdrawal(uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        veloGauge.withdraw(assets);
    }

    function handleDeposit(uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        if (veloPair.allowance(address(this), address(veloGauge)) < assets) {
            veloPair.approve(address(veloGauge), type(uint256).max);
        }
        veloGauge.depositAll(0);
        // veloGauge.deposit(assets, 0);
        console.log(assets);
    }

    function handleClaim() internal virtual override {
        address[] memory tokens = new address[](3);
        tokens[0] = 0x0000000000000000000000000000000000000040;
        tokens[1] = 0x0000000000000000000000000000000000000001;
        tokens[2] = 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05;
        veloGauge.getReward(address(this), tokens);
    }

    function handleFeesAndAdmin() internal virtual override {
        // get balance of reward token
        uint256 rewardBalance = IERC20(rewardToken).balanceOf(address(this));
        // swap reward token to token desired for fee and admin collection
        veloRouter.swapExactTokensForTokens(
            rewardBalance,
            0,
            routeRewardToken,
            address(this),
            block.timestamp
        );
        // get balance of tokens designated for the fee
        uint256 feeBalance = (IERC20(feeCollectionToken).balanceOf(
            address(this)
        ) * feePercent) / 10**6;
        // sent tokens to fee address
        IERC20(rewardToken).transfer(feeAddress, feeBalance);
        // send all rest to admin address for donation
        IERC20(rewardToken).transfer(
            adminAddress,
            IERC20(feeCollectionToken).balanceOf(address(this))
        );
    }

    function viewPendingRewards()
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return veloGauge.earned(rewardToken, address(this));
    }

    function totalAssets() public view virtual override returns (uint256) {
        return veloGauge.balanceOf(address(this));
    }
}
