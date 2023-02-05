// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "hardhat/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "./interfaces/WETH/IWETH.sol";

interface IRillaIndex {
    function feeAddress() external view returns (address);

    function feeOutBps() external view returns (uint256);

    function feeInBps() external view returns (uint256);

    function feeSwapBps() external view returns (uint256);

    function waitTime() external view returns (uint256);

    function interimWaitTime() external view returns (uint256);

    function expireTime() external view returns (uint256);

    function rillaVoteMin() external view returns (uint256);

    function rilla() external view returns (address);

    function rillaSwapRate() external view returns (uint256);

    function treasury() external view returns (address);

    function isRillaSwapLive() external view returns (bool);

    function isAcceptedEIN(uint256 EIN) external view returns (bool);

    function createDonation(uint256 amount, uint256 EIN) external;

    function swapRilla(address sender, uint256 amount) external;
}

// TODO: change requires for a DAF with 1 owner so there is no wait time
contract DAFImplementation {
    using SafeERC20 for IERC20;
    string public name;
    address[] public owners;
    Donation[] public donations;
    OwnerChange[] public ownerChanges;
    Swap[] public swaps;
    mapping(address => uint256) public availableFunds;
    address[] public availableTokens;

    // =========================================================
    // ============== STATE VARS WITH SETTER ===================
    // =========================================================
    address public rillaIndex;
    address public treasuryAddress;

    // =========================================================
    // ===================== CONSTANTS =========================
    // =========================================================
    uint256 constant BPS = 10000;
    address constant usdc = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address constant weth = 0x4200000000000000000000000000000000000006;
    address constant swap0x = 0xDEF1ABE32c034e558Cdd535791643C58a13aCC10;
    uint8 constant maxOwners = 10;

    function initialize(
        address _rillaIndex,
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
        rillaIndex = _rillaIndex;
        success = true;
        availableTokens.push(weth);
        availableTokens.push(usdc);
    }

    // =======================================================================
    // ===================== GENERAL FUNCTIONS ===============================
    // =======================================================================

    // =======================================================================
    // ===================== PUBLIC VIEW FUNCTIONS ===========================
    // =======================================================================
    function getAvailableFunds()
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256 length = availableTokens.length;
        address[] memory tokens = new address[](length);
        uint256[] memory balances = new uint256[](length);
        for (uint256 i = 0; i < length; ++i) {
            tokens[i] = availableTokens[i];
            balances[i] = availableFunds[tokens[i]];
        }
        return (tokens, balances);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function voteIsPassing(uint256 id, VoteType voteType)
        public
        view
        returns (bool out)
    {
        if (voteType == VoteType.DONATION) {
            Donation storage donation = donations[id];
            (out, ) = voteIsPassing(donation.votes, donation.createTime);
        } else if (voteType == VoteType.OWNERCHANGE) {
            OwnerChange storage ownerChange = ownerChanges[id];
            (out, ) = voteIsPassing(ownerChange.votes, ownerChange.createTime);
        } else {
            Swap storage swap = swaps[id];
            (out, ) = voteIsPassing(swap.votes, swap.createTime);
        }
    }

    function executeSwap0x(
        address token,
        uint256 amount,
        bytes memory swapCallData
    ) internal {
        if (IERC20(token).allowance(address(this), swap0x) < amount) {
            IERC20(token).safeApprove(address(swap0x), type(uint256).max);
        }
        (bool success, ) = swap0x.call(swapCallData);
        require(success, "0x swap unsuccessful");
    }

    function abs(int256 x) private pure returns (int256) {
        return x >= 0 ? x : -x;
    }

    function updateFundsAvailable(address token) public {
        availableFunds[token] = IERC20(token).balanceOf(address(this));
    }

    function donateToDaf(
        address token,
        uint256 amount,
        bytes calldata swapCallData
    ) public {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        chargeFee(token, amount, FeeType.IN, swapCallData);
        if (availableFunds[token] == 0) {
            availableTokens.push(token);
        }
        updateFundsAvailable(token);
        emit DonationIn(token, amount);
    }

    function donateEthToDaf(bytes calldata swapCallData) public payable {
        IWETH(weth).deposit{value: msg.value}();
        chargeFee(weth, msg.value, FeeType.IN, swapCallData);
        updateFundsAvailable(weth);
        emit DonationIn(weth, msg.value);
    }

    // =======================================================================
    // ===================== VOTE CREATE FUNCTIONS ===========================
    // =======================================================================
    function createOutDonation(uint256 amount, uint256 EIN)
        public
        onlyDafMember
    {
        require(
            IRillaIndex(rillaIndex).isAcceptedEIN(EIN),
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
        // create new donation to be put up for voting
    }

    function createOwnerChange(address[] calldata _owners, bool add)
        public
        onlyDafMember
    {
        require(_owners.length + owners.length < 11, "Max 10 owners");
        OwnerChange storage vote = ownerChanges.push();
        vote.createTime = uint64(block.timestamp);
        vote.add = add;
        for (uint256 i = 0; i < _owners.length; ++i) {
            vote.owners.push(_owners[i]);
        }

        emit OwnerVoteCreation(msg.sender, _owners, add);
    }

    // DONE
    function createSwap(
        address fromToken,
        address toToken,
        uint256 amount
    ) public onlyDafMember onlyRillaHolder(0) {
        Swap storage swap = swaps.push();
        swap.from = fromToken;
        swap.to = toToken;
        swap.amount = amount;
        swap.createTime = uint64(block.timestamp);
    }

    // =======================================================================
    // ===================== VOTE RELATED FUNCTIONS ==========================
    // =======================================================================
    enum VoteType {
        DONATION,
        OWNERCHANGE,
        SWAP
    }

    function dafVote(
        uint256 id,
        int256 vote,
        VoteType voteType
    )
        public
        onlyDafMember
        onlyRillaHolder(vote)
        onlyUnfinalizedVote(id, voteType)
    {
        uint256 balance = IERC20(IRillaIndex(rillaIndex).rilla()).balanceOf(
            msg.sender
        );
        if (abs(int256(balance)) > vote) {
            // set to max voting power if not enough
            vote = vote > 0 ? int256(balance) : -int256(balance);
        }
        if (voteType == VoteType.DONATION) {
            donations[id].votes[msg.sender] = vote;
        } else if (voteType == VoteType.OWNERCHANGE) {
            ownerChanges[id].votes[msg.sender] = vote;
        } else if (voteType == VoteType.SWAP) {
            swaps[id].votes[msg.sender] = vote;
        }
    }

    function voteIsPassedOnCurrentVotePower(
        int256 voteResult,
        uint256 votePowerUsed,
        uint256 votesRemaining
    ) internal pure returns (bool) {
        return
            votePowerUsed >= 5000 &&
            voteResult >= 0 &&
            uint256(voteResult) >= votesRemaining;
    }

    // if votes are greater than 50% and voteResult is negative and voteresult is further negative than there are votes left, it fails
    function voteIsFailedOnCurrentVotePower(
        int256 voteResult,
        uint256 votePowerUsed,
        uint256 votesRemaining
    ) internal pure returns (bool) {
        return
            votePowerUsed >= 5000 &&
            voteResult < 0 &&
            uint256(abs(voteResult)) >= votesRemaining;
    }

    function voteIsPassing(
        mapping(address => int256) storage votes,
        uint64 createTime
    ) internal view returns (bool passing, string memory errorMessage) {
        // (int256 voteResult, uint256 votePowerUsed)
        // voteResult varies from -BPS to 10000
        // votePowerUsed varies from 0 - BPS, measure of how much voting power in BPS was used
        // if (votePowerUsed >= 5000 && voteResult >= BPS - votePowerUsed) // if votes used are greater than 50% and if the voteResult is further positive than the total votes remaining, it is a valid vote
        // if (votePowerUsed >= 5000 && voteResult < 0 && -voteResult >= BPS - votePowerUsed) // if votes are greater than 50% and voteresult is negative and voteresult is further negative than there are votes left, it fails
        (int256 voteResult, uint256 votePowerUsed) = computeVoteBps(votes);
        uint256 votesRemaining = BPS - votePowerUsed;

        if (
            voteIsPassedOnCurrentVotePower(
                voteResult,
                votePowerUsed,
                votesRemaining
            )
        ) {
            passing =
                block.timestamp >=
                createTime + IRillaIndex(rillaIndex).interimWaitTime();
            errorMessage = "Must allow the interim wait time before fulfilling vote";
            // require(
            //     block.timestamp >=
            //         createTime +
            //             IRillaIndex(rillaIndex).getInterimWaitTime(),
            //     "Must allow the interim wait time before fulfilling vote"
            // );
        } else if (
            voteIsFailedOnCurrentVotePower(
                voteResult,
                votePowerUsed,
                votesRemaining
            )
        ) {
            passing = false;
            errorMessage = "Vote failed.";
            // revert("Vote failed.");
        } else if (
            voteResult > 0 &&
            block.timestamp < createTime + IRillaIndex(rillaIndex).expireTime()
        ) {
            passing =
                block.timestamp >=
                createTime + IRillaIndex(rillaIndex).waitTime();
            errorMessage = "Must allow the wait time if voting power < 50%";
            // require(
            //     block.timestamp >=
            //         createTime + IRillaIndex(rillaIndex).getWaitTime(),
            //     "Must allow the wait time if voting power < 50%"
            // );
        }
    }

    function isVoteActive(uint256 id, VoteType voteType)
        public
        view
        returns (bool)
    {
        uint256 createTime;
        bool finalized;
        if (voteType == VoteType.DONATION) {
            createTime = donations[id].createTime;
            finalized = donations[id].finalized;
        } else if (voteType == VoteType.OWNERCHANGE) {
            createTime = ownerChanges[id].createTime;
            finalized = ownerChanges[id].finalized;
        } else {
            createTime = swaps[id].createTime;
            finalized = swaps[id].finalized;
        }
        return
            block.timestamp >= createTime &&
            createTime <
            block.timestamp + IRillaIndex(rillaIndex).expireTime() &&
            !finalized;
    }

    function computeGeneralVoteBps(uint256 id, VoteType voteType)
        public
        view
        returns (int256 voteResult, uint256 votePowerUsed)
    {
        if (voteType == VoteType.DONATION) {
            return computeVoteBps(donations[id].votes);
        } else if (voteType == VoteType.OWNERCHANGE) {
            return computeVoteBps(ownerChanges[id].votes);
        } else if (voteType == VoteType.SWAP) {
            return computeVoteBps(swaps[id].votes);
        }
    }

    function computeVoteBps(mapping(address => int256) storage votes)
        internal
        view
        returns (int256 voteResult, uint256 votePowerUsed)
    {
        uint256[] memory votingPower = new uint256[](owners.length);
        uint256 votingPowerSum;
        for (uint256 i = 0; i < owners.length; ++i) {
            votingPower[i] = IERC20(IRillaIndex(rillaIndex).rilla()).balanceOf(
                owners[i]
            );
            votingPowerSum += votingPower[i];
            voteResult += votes[owners[i]];
            votePowerUsed += uint256(abs(votes[owners[i]]));
        }
        voteResult = (int256(BPS) * voteResult) / int256(votingPowerSum);
        votePowerUsed = (BPS * votePowerUsed) / votingPowerSum;
    }

    // =======================================================================
    // ===================== FULFILLMENT FUNCTIONS ===========================
    // =======================================================================
    function fulfillDonation(uint256 donationId) public {
        Donation storage donation = donations[donationId];

        // check for expired status
        require(
            isVoteActive(donationId, VoteType.DONATION),
            "Vote has expired."
        );
        (bool passing, string memory errorMessage) = (
            voteIsPassing(donation.votes, donation.createTime)
        );
        require(passing, errorMessage);

        // charge fees
        uint256 outFee = chargeFee(
            usdc,
            donation.amount,
            FeeType.OUT,
            new bytes(0)
        );
        IERC20(usdc).safeTransfer(rillaIndex, donation.amount - outFee);
        // bookkeeping
        donation.finalized = true;
        updateFundsAvailable(usdc);

        // log in index
        IRillaIndex(rillaIndex).createDonation(
            donation.amount - outFee,
            donation.EIN
        );
        emit DonationOut(donation.amount - outFee, donation.EIN);
    }

    function fulfillOwnerChange(uint256 voteId) public onlyDafMember {
        OwnerChange storage ownerChange = ownerChanges[voteId];

        // check for expired status
        require(isVoteActive(voteId, VoteType.OWNERCHANGE), "Vote expired.");
        (bool passing, string memory errorMessage) = (
            voteIsPassing(ownerChange.votes, ownerChange.createTime)
        );
        require(passing, errorMessage);

        address[] memory _owners = ownerChanges[voteId].owners;
        if (ownerChanges[voteId].add) {
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
                // if index is found, overwrite entry to delete and then and pop last entry
                if (idx < maxOwners) {
                    owners[idx] = owners[owners.length - 1];
                    owners.pop();
                } else {
                    revert("Owner not found");
                }
            }
            emit OwnersChanged(_owners, false);
        }
    }

    function fulfillSwap(
        uint256 swapId,
        bytes calldata swapCallData,
        bytes calldata swapCallDataFee
    ) public {
        Swap storage swap = swaps[swapId];

        // check for expired status
        require(isVoteActive(swapId, VoteType.SWAP), "Vote expired.");
        (bool passing, string memory errorMessage) = (
            voteIsPassing(swap.votes, swap.createTime)
        );
        require(passing, errorMessage);

        require(availableFunds[swap.from] >= swap.amount);
        // get balances
        // uint256 prevFrom = IERC20(swap.from).balanceOf(address(this));
        uint256 prevTo = IERC20(swap.to).balanceOf(address(this));
        // execute swap
        executeSwap0x(swap.from, swap.amount, swapCallData);
        uint256 newTo = IERC20(swap.to).balanceOf(address(this));
        // charge fee after swap
        chargeFee(swap.to, newTo - prevTo, FeeType.SWAP, swapCallDataFee);

        // get new balances
        // uint256 curFrom = IERC20(swap.from).balanceOf(address(this));
        // uint256 curTo = IERC20(swap.to).balanceOf(address(this));

        // book keeping
        if (availableFunds[swap.to] == 0) {
            availableTokens.push(swap.to);
        }
        updateFundsAvailable(swap.from);
        updateFundsAvailable(swap.to);

        emit DafSwap(swap.from, swap.to, swap.amount);
    }

    // =======================================================================
    // ================================= FEES ================================
    // =======================================================================
    enum FeeType {
        IN,
        OUT,
        SWAP
    }

    function chargeFee(
        address token,
        uint256 totalAmount,
        FeeType feeType,
        bytes memory swapCallData
    ) internal returns (uint256) {
        // calculate token fee
        uint256 fee;
        if (feeType == FeeType.IN) {
            fee = IRillaIndex(rillaIndex).feeInBps();
        } else if (feeType == FeeType.OUT) {
            fee = IRillaIndex(rillaIndex).feeOutBps();
        } else if (feeType == FeeType.SWAP) {
            fee = IRillaIndex(rillaIndex).feeSwapBps();
        }

        uint256 amount = (totalAmount * fee) / BPS;
        if (token == usdc) {
            if (feeType == FeeType.IN) {
                IRillaIndex(rillaIndex).swapRilla(msg.sender, amount);
            }
            IERC20(usdc).safeTransfer(
                IRillaIndex(rillaIndex).feeAddress(),
                amount
            );
            return amount;
        }
        uint256 usdcPrevBal = IERC20(usdc).balanceOf(address(this));

        // execute swap
        executeSwap0x(token, amount, swapCallData);

        uint256 usdcCurBal = IERC20(usdc).balanceOf(address(this));
        require(usdcCurBal - usdcPrevBal > 0, "0x route invalid");
        IERC20(usdc).safeTransfer(
            IRillaIndex(rillaIndex).feeAddress(),
            usdcCurBal - usdcPrevBal
        );
        if (feeType == FeeType.IN) {
            IRillaIndex(rillaIndex).swapRilla(
                msg.sender,
                usdcCurBal - usdcPrevBal
            );
        }
        return usdcCurBal - usdcPrevBal;
    }

    // =======================================================================
    // ============================= FETCHING ================================
    // =======================================================================
    struct ViewDonations {
        uint256 id;
        uint256 amount;
        uint32 EIN;
        uint64 createTime;
        bool finalized;
    }

    function fetchActiveDonations()
        external
        view
        returns (ViewDonations[] memory, uint256)
    {
        uint256 length = donations.length;
        ViewDonations[] memory votes = new ViewDonations[](length);
        uint256 head = 0;
        bool lenOver50 = length > 50;
        for (uint256 i = length; lenOver50 ? i > length - 50 : i > 0; i--) {
            // only grab last 50 max
            uint256 idx = i - 1;
            if (isVoteActive(idx, VoteType.DONATION)) {
                ViewDonations memory vote = votes[head];
                vote.id = idx;
                vote.amount = donations[idx].amount;
                vote.EIN = donations[idx].EIN;
                vote.createTime = donations[idx].createTime;
                vote.finalized = donations[idx].finalized;
                head++;
            }
        }
        return (votes, head);
    }

    struct ViewOwnerVotes {
        uint256 id;
        bool add;
        bool finalized;
        address[] owners;
    }

    // Only for viewing
    function fetchActiveOwnerChanges()
        external
        view
        returns (ViewOwnerVotes[] memory, uint256)
    {
        uint256 length = ownerChanges.length;
        ViewOwnerVotes[] memory votes = new ViewOwnerVotes[](length);
        uint256 head = 0;
        bool lenOver50 = length > 50;
        for (uint256 i = length - 1; lenOver50 ? i > length - 50 : i > 0; --i) {
            // only grab last 50 max
            uint256 idx = i - 1;
            if (isVoteActive(idx, VoteType.OWNERCHANGE)) {
                ViewOwnerVotes memory vote = votes[head];
                vote.id = idx;
                vote.add = ownerChanges[idx].add;
                vote.finalized = ownerChanges[idx].finalized;
                vote.owners = ownerChanges[idx].owners;
                head++;
            }
        }
        return (votes, head);
    }

    struct ViewSwaps {
        uint256 id;
        bool finalized;
        uint256 amount;
        address from;
        address to;
        string toSymbol;
        string fromSymbol;
        uint256 toDecimals;
        uint256 fromDecimals;
    }

    // Only for viewing
    function fetchActiveSwaps()
        external
        view
        returns (ViewSwaps[] memory, uint256)
    {
        ViewSwaps[] memory viewSwaps = new ViewSwaps[](swaps.length);
        uint256 head = 0;
        uint256 length = swaps.length;
        bool lenOver50 = length > 50;
        for (uint256 i = length; lenOver50 ? i > length - 50 : i > 0; i--) {
            uint256 idx = i - 1;
            // only grab last 50 max
            if (isVoteActive(idx, VoteType.SWAP)) {
                ViewSwaps memory swap = viewSwaps[head];
                swap.id = idx;
                swap.finalized = swaps[idx].finalized;
                swap.amount = swaps[idx].amount;
                swap.from = swaps[idx].from;
                swap.to = swaps[idx].to;
                swap.toSymbol = IERC20Metadata(swap.to).symbol();
                swap.toDecimals = IERC20Metadata(swap.to).decimals();
                swap.fromSymbol = IERC20Metadata(swap.from).symbol();
                swap.fromDecimals = IERC20Metadata(swap.from).decimals();
                head++;
            }
        }
        return (viewSwaps, head);
    }

    function getSwapsLength() external view returns (uint256) {
        return swaps.length;
    }

    function getDonationsLength() external view returns (uint256) {
        return donations.length;
    }

    function getOwnerChangesLength() external view returns (uint256) {
        return ownerChanges.length;
    }

    // =========================================================
    // =========== EVENTS, MODIFIERS, AND STRUCTS  =============
    // =========================================================
    event DonationIn(address token, uint256 amount);
    event DonationOut(uint256 amount, uint32 EIN);
    event DafSwap(address from, address to, uint256 amount);
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

    modifier onlyUnfinalizedVote(uint256 id, VoteType voteType) {
        if (voteType == VoteType.DONATION) {
            require(!donations[id].finalized, "Vote already finalized.");
        } else if (voteType == VoteType.OWNERCHANGE) {
            require(!ownerChanges[id].finalized, "Vote already finalized.");
        } else if (voteType == VoteType.SWAP) {
            require(!swaps[id].finalized, "Vote already finalized.");
        }
        _;
    }

    modifier onlyRillaHolder(int256 voteSize) {
        uint256 balance = IERC20(IRillaIndex(rillaIndex).rilla()).balanceOf(
            msg.sender
        );
        require(
            balance >= uint256(abs(voteSize)) &&
                balance > IRillaIndex(rillaIndex).rillaVoteMin(),
            "Not enough RILLA voting power"
        );
        _;
    }

    struct Donation {
        uint64 createTime;
        bool finalized;
        uint256 amount;
        uint32 EIN;
        mapping(address => int256) votes;
    }

    struct OwnerChange {
        uint64 createTime;
        bool finalized;
        bool add;
        address[] owners;
        mapping(address => int256) votes;
    }

    struct Swap {
        uint64 createTime;
        bool finalized;
        uint256 amount;
        address from;
        address to;
        mapping(address => int256) votes;
    }
}
