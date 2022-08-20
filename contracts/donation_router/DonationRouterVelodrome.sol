// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVelodromeRouter} from "../interfaces/Velodrome/IVelodromeRouter.sol";
import {IWETH} from "../interfaces/WETH/IWETH.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "hardhat/console.sol";

contract DonationRouterVelodrome is Ownable {
    using SafeERC20 for IERC20;
    address public charityAddress;
    address public feeAddress;
    uint256 public fee;
    IVelodromeRouter public router;
    IERC20 public acceptedToken;
    IWETH public immutable weth;
    IVelodromeRouter.route[] ethToAcceptedToken;
    uint256 public constant FEEDIVISOR = 10**6;

    constructor(
        address _charityAddress,
        address _feeAddress,
        uint256 _fee,
        address _acceptedToken,
        address _router,
        address _weth,
        IVelodromeRouter.route[] memory _ethToAcceptedToken
    ) {
        charityAddress = _charityAddress;
        feeAddress = _feeAddress;
        fee = _fee;
        router = IVelodromeRouter(_router);
        acceptedToken = IERC20(_acceptedToken);
        weth = IWETH(_weth);
        for (uint256 i = 0; i < _ethToAcceptedToken.length; i++) {
            ethToAcceptedToken.push(_ethToAcceptedToken[i]);
        }
    }

    /// @notice make sure the allowance is good and approve if not, then swap tokens
    /// @dev implemented after all swaps are complete OR if the donating token is the same as acceptedToken
    function _swapForAcceptedToken(
        IVelodromeRouter.route[] memory route,
        IERC20 asset,
        uint256 donateAmount,
        uint256 minOut
    ) internal {
        // if erc20 approval is not given yet from this address, give it approval
        if (asset.allowance(address(this), address(router)) < donateAmount) {
            asset.safeApprove(address(router), type(uint256).max);
        }
        router.swapExactTokensForTokens(
            donateAmount,
            minOut,
            route,
            address(this),
            block.timestamp
        );
    }

    /// @notice calculates and sends fees to both the fee address and charity addresses
    /// @dev implemented after all swaps are complete OR if the donating token is the same as acceptedToken
    function _donateAndChargeFees() internal {
        acceptedToken.safeTransfer(
            feeAddress,
            (acceptedToken.balanceOf(address(this)) * fee) / FEEDIVISOR
        );
        acceptedToken.safeTransfer(
            charityAddress,
            acceptedToken.balanceOf(address(this))
        );
    }

    /// @notice Donate any ERC20 that has liquidity on the Dex integrated in this contract
    /// @param route Path of tokens that will be passed to the Dex router to exchange to our accepted fee tokens
    /// @param asset The contract address of the token being donated
    /// @param donateAmount The amount of asset that is being donated
    /// @param minOut The minimum amount of tokens to receive
    function donate(
        IVelodromeRouter.route[] memory route,
        IERC20 asset,
        uint256 donateAmount,
        uint256 minOut
    ) public {
        // transfer to this address
        asset.safeTransferFrom(msg.sender, address(this), donateAmount);
        if (address(acceptedToken) == address(asset)) {
            _donateAndChargeFees();
            return;
        }
        require(
            route[route.length - 1].to == address(acceptedToken),
            "Cannot swap to an arbitrary token"
        );
        // execute swap
        _swapForAcceptedToken(route, asset, donateAmount, minOut);
        _donateAndChargeFees();
    }

    /// @notice Donate Eth on the Dex integrated in this contract
    /// @param route Path of tokens that will be passed to the Dex router to exchange to our accepted fee tokens
    /// @param minOut The minimum amount of tokens to receive
    function donateEth(IVelodromeRouter.route[] memory route, uint256 minOut)
        public
        payable
    {
        require(
            route[route.length - 1].to == address(acceptedToken),
            "Cannot swap to an arbitrary token"
        );
        router.swapExactETHForTokens{value: msg.value}(
            minOut,
            route,
            address(this),
            block.timestamp
        );
        _donateAndChargeFees();
    }

    /// @notice Explain to an end user what this does
    /// @param _fee Fee to change internal fee to
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }
}
