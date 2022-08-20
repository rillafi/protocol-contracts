// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "../interfaces/WETH/IWETH.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "hardhat/console.sol";

contract DonationRouter is Ownable {
    using SafeERC20 for IERC20;
    address public charityAddress;
    address public feeAddress;
    address public swap0x;
    uint256 public fee;
    IERC20 public acceptedToken;
    IWETH public immutable weth;
    uint256 public constant FEEDIVISOR = 10**6;

    constructor(
        address _charityAddress,
        address _feeAddress,
        uint256 _fee,
        address _acceptedToken,
        address _weth,
        address _swap0x
    ) {
        charityAddress = _charityAddress;
        feeAddress = _feeAddress;
        fee = _fee;
        acceptedToken = IERC20(_acceptedToken);
        weth = IWETH(_weth);
        swap0x = _swap0x;
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

    /// @notice Donate any ERC20 that has liquidity on the Dex integrated in this contract. Handles cases for all different tokens as well as the chain's native asset
    /// @param sellToken the address of the token being provided as donation
    /// @param sellAmount number of tokens being provided as donation
    /// @param swapCallData data from 0x quote used to call 0x contract to execute ERC20 swap
    /// @dev if donating with native asset (ETH) set sellToken to WETH's address, msg.value to desired Eth donation
    /// @dev if donating with acceptedToken then it's fine to send empty bytes to swapCallData ("0x")
    function donate(
        IERC20 sellToken,
        uint256 sellAmount,
        bytes calldata swapCallData
    ) public payable {
        if (sellToken == acceptedToken) {
            sellToken.safeTransferFrom(msg.sender, address(this), sellAmount);
            _donateAndChargeFees();
            return;
        }
        // swap required
        require(
            bytesToAddress(swapCallData[48:68]) == address(acceptedToken),
            "0x Route invalid"
        );
        // eth or token deposit
        if (msg.value == 0) {
            sellToken.safeTransferFrom(msg.sender, address(this), sellAmount);
            if (
                sellToken.allowance(address(this), address(swap0x)) < sellAmount
            ) {
                sellToken.safeApprove(address(swap0x), type(uint256).max);
            }
        }
        (bool success, ) = swap0x.call{value: msg.value}(swapCallData);
        require(success, "swap unsuccessful");
        _donateAndChargeFees();
    }

    /// @notice input bytes of length 20, output address
    function bytesToAddress(bytes memory bys)
        private
        pure
        returns (address addr)
    {
        assembly {
            addr := mload(add(bys, 20))
        }
    }

    /// @notice Setter for fee variable
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }
}
