// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import {RILLAVault} from "../../../RILLAVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVeloGauge {
    function depositAll(uint256 tokenId) external;

    function getReward(address account, address[] memory tokens) external;

    function withdraw(uint256 amount) external;

    function earned(address token, address account)
        external
        view
        returns (uint256);

    function balanceOf(address user) external view returns (uint256);
}

interface IVeloPair {
    function token0() external returns (address);

    function stable() external returns (bool);
}

interface IVeloRouter {
    struct route {
        address from;
        address to;
        bool stable;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        route[] calldata routes,
        address to,
        uint256 deadline
    ) external;

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external;
}

contract rillaVeloVault is RILLAVault {
    IVeloGauge veloGauge;
    IVeloPair veloPair;
    address token0;
    address token1;
    address rewardToken;
    address feeCollectionToken;
    IVeloRouter public immutable veloRouter =
        IVeloRouter(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);
    IVeloRouter.route[] public routeToken0;
    IVeloRouter.route[] public routeToken1;
    IVeloRouter.route[] public routeFeeToken;

    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        address _yieldSource,
        uint256 _feePercent,
        address _feeAddress,
        address _adminAddress,
        address _veloGauge,
        address _token0,
        address _token1,
        address _rewardToken,
        IVeloRouter.route[] memory _routeToken0,
        IVeloRouter.route[] memory _routeToken1,
        IVeloRouter.route[] memory _routeFeeToken
    )
        RILLAVault(
            _asset,
            _name,
            _symbol,
            _yieldSource,
            _feePercent,
            _feeAddress,
            _adminAddress
        )
    {
        veloGauge = IVeloGauge(_veloGauge);
        veloPair = IVeloPair(_asset);
        rewardToken = _rewardToken;
        routeFeeToken = _routeFeeToken;
        if (veloPair.token0() == _token0) {
            token0 = _token0;
            token1 = _token1;
            routeToken0 = _routeToken0;
            routeToken1 = _routeToken1;
        } else {
            token0 = _token1;
            token1 = _token0;
            routeToken0 = _routeToken1;
            routeToken1 = _routeToken0;
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
        veloGauge.depositAll(0);
    }

    function handleClaim() internal virtual override {
        address[] memory tokens = new address[](3);
        tokens[0] = 0x0000000000000000000000000000000000000040;
        tokens[1] = 0x0000000000000000000000000000000000000001;
        tokens[3] = 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05;
        veloGauge.getReward(address(this), tokens);
    }

    function handleFeesAndAdmin() internal virtual override {
        // get balance of reward token
        uint256 rewardBalance = IERC20(rewardToken).balanceOf(address(this));
        // swap reward token to token desired for fee and admin collection
        veloRouter.swapExactTokensForTokens(
            rewardBalance,
            0,
            routeFeeToken,
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
