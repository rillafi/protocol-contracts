// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "./interfaces/WETH/IWETH.sol";
import {console} from "hardhat/console.sol";

interface IRillaIndex {
    function getFeeAddress() external view returns (address);

    function getOutFeeBps() external view returns (uint256);

    function getInFeeBps() external view returns (uint256);

    function getWaitTime() external view returns (uint256);

    function getInterimWaitTime() external view returns (uint256);

    function getExpireTime() external view returns (uint256);

    function getVoteMin() external view returns (uint256);

    function getVeRillaAddress() external view returns (address);

    function createDonation(uint256 amount, uint256 EIN) external;

    function isAcceptedEIN(uint256 EIN) external view returns (bool);
}

// TODO: Create dafAssets mapping 
// TODO: Create function to reconcile balances caused by transferring token directly to DAF
contract DAFImplementation {
    using SafeERC20 for IERC20;
    string public name;
    // mapping(address => bool) owners; // not sure if we can do hashmap as we need to check votes from multiple parties
    address[] public owners;
    Donation[] public donations;
    VoteOwnerChange[] ownerChangeVotes;

    // =========================================================
    // ============== STATE VARS WITH SETTER ===================
    // =========================================================
    address indexAddress;

    // =========================================================
    // ===================== CONSTANTS =========================
    // =========================================================
    uint256 constant BPS = 10000;
    address constant usdc = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address constant weth = 0x4200000000000000000000000000000000000006;
    address constant swap0x = 0xDEF1ABE32c034e558Cdd535791643C58a13aCC10;
    uint8 constant maxOwners = 10;

    function initialize(
        address _indexAddress,
        string memory _name,
        address[] memory _owners
    ) external returns (bool success) {
        success = false;
        require(owners.length == 0, "Contract already initialized");
        require(_owners.length <= maxOwners, "Max 10 owners");

        for (uint256 i = 0; i < _owners.length; i++) {
            owners.push(_owners[i]);
        }
        name = _name;
        indexAddress = _indexAddress;
        success = true;
    }

    function donateToDaf(
        address token,
        uint256 amount,
        bytes calldata swapCallData
    ) public {
        // transfer to this DAF
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        // charge in fee?
        chargeFeeIn(token, amount, swapCallData);

        emit DonationIn(token, amount);
    }

    function donateEthToDaf(bytes calldata swapCallData) public payable {
        // transfer to this DAF
        IWETH(weth).deposit{value: msg.value}();

        // charge in fee
        chargeFeeIn(weth, msg.value, swapCallData);

        emit DonationIn(weth, msg.value);
    }

    function executeSwap0x(
        address token,
        uint256 amount,
        bytes calldata swapCallData
    ) internal {
        if (IERC20(token).allowance(address(this), swap0x) < amount) {
            IERC20(token).safeApprove(address(swap0x), type(uint256).max);
        }
        (bool success, ) = swap0x.call(swapCallData);
        require(success, "0x swap unsuccessful");
    }

    function chargeFeeIn(
        address token,
        uint256 totalAmount,
        bytes calldata swapCallData
    ) internal {
        // calculate token fee
        uint256 amount = (totalAmount *
            IRillaIndex(indexAddress).getInFeeBps()) / BPS;
        if (token == usdc) {
            IERC20(usdc).safeTransfer(
                IRillaIndex(indexAddress).getFeeAddress(),
                amount
            );
            return;
        }
        uint256 usdcPrevBal = IERC20(usdc).balanceOf(address(this));

        // execute swap
        executeSwap0x(token, amount, swapCallData);

        uint256 usdcCurBal = IERC20(usdc).balanceOf(address(this));
        require(usdcCurBal - usdcPrevBal > 0, "0x route invalid");
        IERC20(usdc).safeTransfer(
            IRillaIndex(indexAddress).getFeeAddress(),
            usdcCurBal - usdcPrevBal
        );
    }

    function chargeFeeOut(uint256 totalAmount) internal returns (uint256) {
        uint256 amount = (totalAmount *
            IRillaIndex(indexAddress).getOutFeeBps()) / BPS;
        IERC20(usdc).safeTransfer(
            IRillaIndex(indexAddress).getFeeAddress(),
            amount
        );
        return amount;
    } // This should be USDC already

    function createOwnerChange(address[] calldata _owners, bool add)
        public
        onlyDafMember
    {
        require(_owners.length + owners.length < 11, "Max 10 owners");
        VoteOwnerChange storage vote = ownerChangeVotes.push();
        vote.createTime = uint64(block.timestamp);
        vote.add = add;
        for (uint256 i = 0; i < _owners.length; ++i) {
            vote.owners.push(_owners[i]);
        }

        emit OwnerVoteCreation(msg.sender, _owners, add);
    }

    function voteOwnerChange(uint256 voteId, int256 vote)
        public
        onlyDafMember
        onlyUnfinalizedVote(voteId)
    {
        uint256 balance = IERC20(IRillaIndex(indexAddress).getVeRillaAddress())
            .balanceOf(msg.sender);
        require(
            balance >= uint256(abs(vote)) &&
                balance > IRillaIndex(indexAddress).getVoteMin(),
            "Not enough RILLA voting power"
        );
        require(
            block.timestamp < ownerChangeVotes[voteId].createTime + 1 weeks,
            "Vote is no longer valid"
        );
        ownerChangeVotes[voteId].votes[msg.sender] = vote;
    }

    function fulfillOwnerChange(uint256 voteId) public onlyDafMember {
        VoteOwnerChange storage ownerChange = ownerChangeVotes[voteId];
        (int voteResult, uint votePower) = computeVoteBps(ownerChange.votes);

        require(votePower >= 5000, "Not enough votes");
        require(voteResult > 0, "Vote is negative");
        require(
            block.timestamp < ownerChangeVotes[voteId].createTime + 1 weeks,
            "Vote expired"
        );

        address[] memory _owners = ownerChangeVotes[voteId].owners;
        if (ownerChangeVotes[voteId].add) {
            for (uint256 i = 0; i < _owners.length; ++i) {
                owners.push(_owners[i]);
            }
            emit OwnersChanged(_owners, true);
        } else {
            for (uint256 i = 0; i < _owners.length; ++i) {
                // find index in array
                uint256 idx = maxOwners;
                for (uint256 j = 0; j < owners.length; ++j) {
                    if (owners[j] == _owners[i]) {
                        idx = j;
                        break;
                    }
                }
                // if index is found, overwrite and pop last entry
                if (idx < maxOwners) {
                    owners[idx] = owners[owners.length - 1];
                    owners.pop();
                }
            }
            emit OwnersChanged(_owners, false);
        }
    }

    function freeFundsForDonation(
        address tokenAddress,
        uint256 amount,
        bytes calldata swapCallData
    ) public {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Not enough funds");
        uint256 usdcPrevBal = IERC20(usdc).balanceOf(address(this));
        // execute swap
        executeSwap0x(tokenAddress, amount, swapCallData);
        // check usdc balance increases
        uint256 usdcCurBal = IERC20(usdc).balanceOf(address(this));
        require(usdcCurBal - usdcPrevBal > 0, "0x route invalid");
    }

    function createOutDonation(uint256 amount, uint256 EIN)
        public
        onlyDafMember
    {
        require(
            IRillaIndex(indexAddress).isAcceptedEIN(EIN),
            "Charity not enabled"
        );
        require(
            IERC20(usdc).balanceOf(address(this)) >= amount,
            "RILLA: Not enough funds"
        );

        Donation storage newDonation = donations.push();
        newDonation.amount = amount;
        newDonation.EIN = uint32(EIN);
        newDonation.createTime = uint64(block.timestamp);
    } // create new donation to be put up for voting

    function voteOutDonation(uint256 donationId, int256 vote)
        public
        onlyDafMember
        onlyUnfulfilledDonation(donationId)
    {
        uint256 balance = IERC20(IRillaIndex(indexAddress).getVeRillaAddress())
            .balanceOf(msg.sender);
        if (abs(int256(balance)) > vote) {
            // set to max voting power if not enough
            vote = vote > 0 ? int256(balance) : -int256(balance);
        }
        // require(
        //     balance >= uint256(abs(vote)) &&
        //         balance > IRillaIndex(indexAddress).getVoteMin(),
        //     "Not enough RILLA voting power"
        // );
        donations[donationId].votes[msg.sender] = vote;
    } // vote with RILLA

    function fulfillDonation(uint256 donationId) public {
        // (int256 voteResult, uint256 votePowerUsed)
        // voteResult varies from -BPS to 10000
        // votePowerUsed varies from 0 - BPS, measure of how much voting power in BPS was used
        // if (votePowerUsed >= 5000 && voteResult >= BPS - votePowerUsed) // if votes used are greater than 50% and if the voteResult is further positive than the total votes remaining, it is a valid vote
        // if (votePowerUsed >= 5000 && voteResult < 0 && -voteResult >= BPS - votePowerUsed) // if votes are greater than 50% and voteresult is negative and voteresult is further negative than there are votes left, it fails

        Donation storage donation = donations[donationId];
        (int256 voteResult, uint256 votePowerUsed) = computeVoteBps(
            donation.votes
        );
        uint256 votesRemaining = BPS - votePowerUsed;
        // check for expired status
        bool valid = false;
        if (
            block.timestamp >=
            donation.createTime + IRillaIndex(indexAddress).getExpireTime()
        ) {
            revert("Vote expired.");
        }
        // if votes used are greater than 50% and if the voteResult is further positive than the total votes remaining, it is a valid vote
        else if (
            votePowerUsed >= 5000 &&
            voteResult >= 0 &&
            uint256(voteResult) >= votesRemaining
        ) {
            if (
                block.timestamp >=
                donation.createTime +
                    IRillaIndex(indexAddress).getInterimWaitTime()
            ) {
                valid = true;
            } else {
                revert(
                    "Must allow the interim wait time before fulfilling donation"
                );
            }
        }
        // if votes are greater than 50% and voteResult is negative and voteresult is further negative than there are votes left, it fails
        else if (
            votePowerUsed >= 5000 &&
            voteResult < 0 &&
            uint256(abs(voteResult)) >= votesRemaining
        ) {
            revert("Vote failed.");
        } else if (
            voteResult > 0 &&
            block.timestamp <
            donation.createTime + IRillaIndex(indexAddress).getExpireTime()
        ) {
            if (
                block.timestamp >=
                donation.createTime + IRillaIndex(indexAddress).getWaitTime()
            ) {
                valid = true;
            } else {
                revert("Must allow the wait time if voting power < 50%");
            }
        } else {
            require(valid, "Vote is not valid");
        }

        // charge fees
        uint256 outFee = chargeFeeOut(donation.amount);
        IERC20(usdc).safeTransfer(indexAddress, donation.amount - outFee);
        donation.fulfilled = true;

        IRillaIndex(indexAddress).createDonation(
            donation.amount - outFee,
            donation.EIN
        );
        emit DonationOut(donation.amount - outFee, donation.EIN);
    } // If vote is successful, send to fulfillment account

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function computeOwnerVoteBps(uint256 donationId)
        public
        view
        returns (uint256)
    {
        uint256[] memory votingPower;
        uint256 votingPowerSum;
        int256 votesFor;
        Donation storage donation = donations[donationId];
        for (uint256 i = 0; i < owners.length; i++) {
            votingPower[i] = IERC20(
                IRillaIndex(indexAddress).getVeRillaAddress()
            ).balanceOf(owners[i]);
            votingPowerSum += votingPower[i];
            if (donation.votes[owners[i]] > 0) {
                votesFor += donation.votes[owners[i]];
            }
        }
        return (BPS * uint256(votesFor)) / votingPowerSum;
    }

    function computeVoteBps(mapping(address => int256) storage votes)
        internal
        view
        returns (int256 voteResult, uint256 votePowerUsed)
    {
        uint256[] memory votingPower = new uint256[](owners.length);
        uint256 votingPowerSum;
        for (uint256 i = 0; i < owners.length; ++i) {
            votingPower[i] = IERC20(
                IRillaIndex(indexAddress).getVeRillaAddress()
            ).balanceOf(owners[i]);
            votingPowerSum += votingPower[i];
            voteResult += votes[owners[i]];
            votePowerUsed += uint256(abs(votes[owners[i]]));
        }
        voteResult = (int256(BPS) * voteResult) / int256(votingPowerSum);
        votePowerUsed = (BPS * votePowerUsed) / votingPowerSum;
    }

    function computeDonationVoteBps(uint256 donationId)
        public
        view
        returns (int256 voteResult, uint256 votePowerUsed)
    {
        Donation storage donation = donations[donationId];
        return computeVoteBps(donation.votes);
    }

    event DonationIn(address token, uint256 amount);
    event DonationOut(uint256 amount, uint32 EIN);
    event OwnerVoteCreation(
        address creator,
        address[] owners,
        bool addOrRemove
    );
    event OwnersChanged(address[] modified, bool addOrRemove);

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

    modifier onlyUnfinalizedVote(uint256 voteId) {
        require(!ownerChangeVotes[voteId].finalized, "Vote already finalized");
        _;
    }

    modifier onlyUnfulfilledDonation(uint256 donationId) {
        require(!donations[donationId].fulfilled, "Donation already fulfilled");
        _;
    }

    struct Donation {
        uint256 amount;
        uint32 EIN;
        uint64 createTime;
        bool fulfilled;
        mapping(address => int256) votes;
    }

    struct VoteOwnerChange {
        uint64 createTime;
        bool add;
        bool finalized;
        address[] owners;
        mapping(address => int256) votes;
    }

    function abs(int256 x) private pure returns (int256) {
        return x >= 0 ? x : -x;
    }
}
