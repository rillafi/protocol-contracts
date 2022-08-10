// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.4;

// import {IDEX} from "@acala-network/contracts/dex/IDEX.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract Fund {
//     address public charityAddress;
//     address public feeAddress;
//     IDEX public dex;
//     IERC20 public stablecoin;

//     constructor(
//         address _charityAddress,
//         address _feeAddress,
//         address _dex,
//         address _stablecoin
//     ) {
//         charityAddress = _charityAddress;
//         feeAddress = _feeAddress;
//         _dex = IDEX(dex);
//         stablecoin = _stablecoin;
//     }

//     function fundCharity(
//         address[] memory path,
//         IERC20 asset,
//         uint256 supplyAmount
//     ) {
//         // transfer to this address
//         assert(
//             asset.transferFrom(msg.sender, address(this), supplyAmount),
//             "Token transfer to Fund contract not successful"
//         );
//         // if erc20 approval is not given yet from this address, give it
//         if (asset.allowance(address(this), address(dex)) < supplyAmount) {
//             assert(
//                 asset.approve(address(dex), type(uint256).max),
//                 "Token approval unsuccessful"
//             );
//         }
//         // swap the tokens
//         assert(
//             dex.swapWithExactSupply(path, supplyAmount, minTargetAmount),
//             "Dex swap unsuccessful"
//         );
//         // send the tokens to the charity wallet
//         assert(
//             stablecoin.transfer(
//                 charityAddress,
//                 stablecoin.balanceOf(address(this))
//             )
//         );
//     }
// }
