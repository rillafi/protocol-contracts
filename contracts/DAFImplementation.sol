// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "./interfaces/WETH/IWETH.sol";

interface IRillaIndex {
    function getFeeAddress() external view returns (address);

    function getFeePercent() external view returns (uint256);
}

contract DAFImplementation {
    using SafeERC20 for IERC20;
    string name;
    // mapping(address => bool) owners; // not sure if we can do hashmap as we need to check votes from multiple parties
    address[] public owners;

    uint256 minVoteAmount = 100e18;

    address indexAddress = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; // CHANGE

    // =========================================================
    // ===================== CONSTANTS =========================
    // =========================================================
    address constant usdc = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address constant weth = 0x4200000000000000000000000000000000000006;

    function initialize(
        address _indexAddress,
        string memory _name,
        address[] memory _owners
    ) public {
        require(owners.length == 0, "Contract already initialized");

        for (uint256 i = 0; i < _owners.length; i++) {
            owners.push(_owners[i]);
        }
        name = _name;
        indexAddress = _indexAddress;
    }

    function donateToDaf(address token, uint256 amount) public {
        // transfer to this DAF
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        // charge % fee?
        IERC20(token).safeTransfer(
            IRillaIndex(indexAddress).getFeeAddress(),
            (amount * IRillaIndex(indexAddress).getFeePercent()) / 1e4
        );
        emit DonatedToDaf(token, amount);
    }

    function donateEthToDaf() public payable {
        uint256 amount = IWETH(weth).deposit{value: msg.value}();
        // require(
        //     IWETH(weth).transfer(
        //         IRillaIndex(indexAddress).getFeeAddress(),
        //         (amount * IRillaIndex(indexAddress).getFeePercent()) / 1e4
        //     ),
        //     "WETH transfer unsuccessful"
        // );

        // charge % fee?
        IERC20(weth).safeTransfer(
            IRillaIndex(indexAddress).getFeeAddress(),
            (amount * IRillaIndex(indexAddress).getFeePercent()) / 1e4
        );
        emit DonatedToDaf(weth, amount);
    }

    // function chargeFeeIn(); // do we send trade through 0x and give USDC right away?
    // function chargeFeeOut(); // This should be USDC already

    function addOwnersToDaf(address[] memory _owners) public {
        require(owners.length + _owners.length < 11, "10 owners max");
        for (uint256 i = 0; i < _owners.length; i++) {
            owners.push(_owners[i]);
        }
    }

    function freeFundsForDonation(address tokenAddress, uint256 amount) public {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Not enough funds");
        // TODO: trade to USDC through 0x
    }

    function createDonation() public {} // create new donation to be put up for voting

    function voteOnDonation() public {} // vote with RILLA

    function fulfillDonation() public {} // If vote is successful, send to fulfillment account


    function getOwners() public view returns (address[] memory) {
        return owners;
    }
    event DonatedToDaf(address token, uint256 amount);

    modifier onlyDafMember() {
        bool isOwner = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == msg.sender) {
                isOwner = true;
                break;
            }
        }
        require(isOwner, "Sender is not an owner of this DAF.");
        _;
    }
}
