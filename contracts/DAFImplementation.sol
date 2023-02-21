// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

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

    function isPaused() external view returns (bool);

    function isAcceptedEIN(uint256 EIN) external view returns (bool);

    function createDonation(uint256 amount, uint256 EIN) external;

    function rillaFee(
        address token,
        uint256 amount,
        bytes calldata swapCallData
    ) external returns (uint256);
}

// TODO: change requires for a DAF with 1 member so there is no wait time
contract DAFImplementation {
    using SafeERC20 for IERC20;
    string public name;
    address[] public members;
    Donation[] public donations;
    MemberChange[] public memberChanges;
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
    uint8 constant maxMembers = 10;

    /// @notice initializes contract
    /// @dev acts as constructor
    /// @param _rillaIndex Index contract
    /// @param _name Name of DAF
    /// @param _members All members of this DAF
    /// @return success Reports success
    function initialize(
        address _rillaIndex,
        string memory _name,
        address[] memory _members
    ) external returns (bool success) {
        require(members.length == 0, "Contract already initialized");
        require(_members.length <= maxMembers, "Max 10 members");

        for (uint256 i = 0; i < _members.length; i++) {
            members.push(_members[i]);
        }
        name = _name;
        rillaIndex = _rillaIndex;
        availableTokens.push(weth);
        availableTokens.push(usdc);
        success = true;
    }

    // =======================================================================
    // ===================== PUBLIC VIEW FUNCTIONS ===========================
    // =======================================================================
    /// @notice Helper function to grab funds and view
    /// @return tuple of tokens and balances
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

    /// @notice gets members
    /// @return an array of addresses who are members
    function getMembers() public view returns (address[] memory) {
        return members;
    }

    /// @notice Easy check if vote is passing
    /// @param id Id
    /// @param voteType Donation, MemberChange, or Swap
    /// @return isPassing
    function voteIsPassing(uint256 id, VoteType voteType)
        public
        view
        returns (bool isPassing)
    {
        if (voteType == VoteType.DONATION) {
            Donation storage donation = donations[id];
            (isPassing, ) = voteIsPassing(donation.votes, donation.createTime);
        } else if (voteType == VoteType.MEMBERCHANGE) {
            MemberChange storage memberChange = memberChanges[id];
            (isPassing, ) = voteIsPassing(
                memberChange.votes,
                memberChange.createTime
            );
        } else {
            Swap storage swap = swaps[id];
            (isPassing, ) = voteIsPassing(swap.votes, swap.createTime);
        }
    }

    // =======================================================================
    // ===================== GENERAL FUNCTIONS ===============================
    // =======================================================================
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

    /// @notice reconciles balances
    /// @dev Just calls balanceOf, it's fine whoever calls this
    /// @param token Token to determine balance of
    function updateFundsAvailable(address token) public {
        if (availableFunds[token] == 0) {
            availableTokens.push(token);
        }
        availableFunds[token] = IERC20(token).balanceOf(address(this));

        // if it's 0, it's still in the availableTokens array so to avoid pushing that token to that array again, set balance to 1
        if (availableFunds[token] == 0) {
            availableFunds[token] = 1;
        }
    }

    /// @notice Actual donation to the DAF. Anyone can donate to any DAF
    /// @param token Token to donate
    /// @param amount Amount to donate
    /// @param swapCallData For the fee
    function donateToDaf(
        address token,
        uint256 amount,
        bytes calldata swapCallData
    ) public onlyWhenUnpaused {
        // transfer token to here
        if (token == weth) {
            IWETH(weth).deposit{value: amount}();
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        // grant allowances for RillaIndex
        if (IERC20(token).allowance(address(this), rillaIndex) < amount) {
            IERC20(token).safeApprove(address(rillaIndex), type(uint256).max);
        }

        // RillaIndex handles the fee charged
        uint256 rillaAmount = IRillaIndex(rillaIndex).rillaFee(
            token,
            amount,
            swapCallData
        );

        // After receiving RILLA, we send back to msg.sender
        IERC20(IRillaIndex(rillaIndex).rilla()).safeTransfer(
            msg.sender,
            rillaAmount
        );

        // update funds and emit event
        updateFundsAvailable(token);
        emit DonationIn(token, amount);
    }

    /// @notice Accepts ETH native payments
    /// @dev Payable to allow ETH
    function donateEthToDaf(bytes calldata swapCallData) public payable {
        donateToDaf(weth, msg.value, swapCallData);
    }

    // =======================================================================
    // ===================== VOTE CREATE FUNCTIONS ===========================
    // =======================================================================

    /// @notice Creates vote for an out donation
    /// @dev only a member of the daf may do this
    /// @param amount Amount of tokens to donate
    /// @param EIN identifier for charity to donate to
    function createOutDonation(uint256 amount, uint256 EIN)
        public
onlyWhenUnpaused 
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

    /// @notice Creates vote for a member change
    /// @param _members Members to add or remove
    /// @param add Indicates add or remove
    function createMemberChange(address[] calldata _members, bool add)
        public
onlyWhenUnpaused 
        onlyDafMember
    {
        require(_members.length + members.length < 11, "Max 10 members");
        MemberChange storage vote = memberChanges.push();
        vote.createTime = uint64(block.timestamp);
        vote.add = add;
        for (uint256 i = 0; i < _members.length; ++i) {
            vote.members.push(_members[i]);
        }

        emit MemberVoteCreation(msg.sender, _members, add);
    }

    /// @notice Create vote to swap tokens in DAF
    /// @param fromToken Token to swap from
    /// @param toToken Token to swap to
    /// @param amount Amount of fromToken to swap
    function createSwap(
        address fromToken,
        address toToken,
        uint256 amount
    ) public onlyWhenUnpaused onlyDafMember onlyRillaHolder(0) {
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
        MEMBERCHANGE,
        SWAP
    }

    /// @notice Cast vote for an active vote
    /// @param id Id
    /// @param voteType Donation, MemberChange, or Swap
    /// @param vote Vote amount, + is yes and - is no
    function castVote(
        uint256 id,
        int256 vote,
        VoteType voteType
    )
        public
onlyWhenUnpaused 
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
        } else if (voteType == VoteType.MEMBERCHANGE) {
            memberChanges[id].votes[msg.sender] = vote;
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
        } else if (
            voteIsFailedOnCurrentVotePower(
                voteResult,
                votePowerUsed,
                votesRemaining
            )
        ) {
            passing = false;
            errorMessage = "Vote failed.";
        } else if (
            voteResult > 0 &&
            block.timestamp < createTime + IRillaIndex(rillaIndex).expireTime()
        ) {
            passing =
                block.timestamp >=
                createTime + IRillaIndex(rillaIndex).waitTime();
            errorMessage = "Must allow the wait time if voting power < 50%";
        }
    }

    /// @notice Check if vote is active
    /// @param id Id
    /// @param voteType Donation, MemberChange, or Swap
    /// @return True if vote is active
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
        } else if (voteType == VoteType.MEMBERCHANGE) {
            createTime = memberChanges[id].createTime;
            finalized = memberChanges[id].finalized;
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

    /// @notice Computes voteresult and votepowerused
    /// @param id Id
    /// @param voteType Donation, MemberChange, or Swap
    function computeGeneralVoteBps(uint256 id, VoteType voteType)
        public
        view
        returns (int256 voteResult, uint256 votePowerUsed)
    {
        if (voteType == VoteType.DONATION) {
            return computeVoteBps(donations[id].votes);
        } else if (voteType == VoteType.MEMBERCHANGE) {
            return computeVoteBps(memberChanges[id].votes);
        } else if (voteType == VoteType.SWAP) {
            return computeVoteBps(swaps[id].votes);
        }
    }

    function computeVoteBps(mapping(address => int256) storage votes)
        internal
        view
        returns (int256 voteResult, uint256 votePowerUsed)
    {
        uint256[] memory votingPower = new uint256[](members.length);
        uint256 votingPowerSum;
        for (uint256 i = 0; i < members.length; ++i) {
            votingPower[i] = IERC20(IRillaIndex(rillaIndex).rilla()).balanceOf(
                members[i]
            );
            votingPowerSum += votingPower[i];
            voteResult += votes[members[i]];
            votePowerUsed += uint256(abs(votes[members[i]]));
        }
        voteResult = (int256(BPS) * voteResult) / int256(votingPowerSum);
        votePowerUsed = (BPS * votePowerUsed) / votingPowerSum;
    }

    // =======================================================================
    // ===================== FULFILLMENT FUNCTIONS ===========================
    // =======================================================================

    /// @notice Fulfills donation if vote is passing
    /// @param donationId id of donation
    function fulfillDonation(uint256 donationId) public onlyWhenUnpaused onlyDafMember {
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

    /// @notice Fulfills member change if vote is passing
    /// @param voteId id of memberchange vote
    function fulfillMemberChange(uint256 voteId) public onlyWhenUnpaused onlyDafMember {
        MemberChange storage memberChange = memberChanges[voteId];

        // check for expired status
        require(isVoteActive(voteId, VoteType.MEMBERCHANGE), "Vote expired.");
        (bool passing, string memory errorMessage) = (
            voteIsPassing(memberChange.votes, memberChange.createTime)
        );
        require(passing, errorMessage);

        address[] memory _members = memberChanges[voteId].members;
        if (memberChanges[voteId].add) {
            for (uint256 i = 0; i < _members.length; ++i) {
                members.push(_members[i]);
            }
            emit MembersChanged(_members, true);
        } else {
            for (uint256 i = 0; i < _members.length; ++i) {
                // find index in array
                uint256 idx = maxMembers;
                for (uint256 j = 0; j < members.length; ++j) {
                    if (members[j] == _members[i]) {
                        idx = j;
                        break;
                    }
                }
                // if index is found, overwrite entry to delete and then and pop last entry
                if (idx < maxMembers) {
                    members[idx] = members[members.length - 1];
                    members.pop();
                } else {
                    revert("Member not found");
                }
            }
            emit MembersChanged(_members, false);
        }
    }

    /// @notice Fulfills swap if vote is passing
    /// @param swapId id of swap vote
    /// @param swapCallData call data to swap tokens
    /// @param swapCallDataFee swap data for fee in USDC
    function fulfillSwap(
        uint256 swapId,
        bytes calldata swapCallData,
        bytes calldata swapCallDataFee
    ) public onlyWhenUnpaused {
        Swap storage swap = swaps[swapId];

        // check for expired status
        require(isVoteActive(swapId, VoteType.SWAP), "Vote expired.");
        (bool passing, string memory errorMessage) = (
            voteIsPassing(swap.votes, swap.createTime)
        );
        require(passing, errorMessage);
        require(
            availableFunds[swap.from] >= swap.amount,
            "Funds not available in DAF"
        );

        // execute swap, ensure usdc is the 'to' token
        uint256 prevTo = IERC20(swap.to).balanceOf(address(this));
        executeSwap0x(swap.from, swap.amount, swapCallData);
        uint256 newTo = IERC20(swap.to).balanceOf(address(this));

        // charge fee after swap
        chargeFee(swap.to, newTo - prevTo, FeeType.SWAP, swapCallDataFee);

        // book keeping
        updateFundsAvailable(swap.from);
        updateFundsAvailable(swap.to);
        emit DafSwap(swap.from, swap.to, swap.amount);
    }

    // =======================================================================
    // ================================= FEES ================================
    // =======================================================================
    enum FeeType {
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
        if (feeType == FeeType.OUT) {
            fee = IRillaIndex(rillaIndex).feeOutBps();
        } else if (feeType == FeeType.SWAP) {
            fee = IRillaIndex(rillaIndex).feeSwapBps();
        }

        // calculate fee
        uint256 amount = (totalAmount * fee) / BPS;

        // if USDC, no swap needed
        if (token == usdc) {
            IERC20(usdc).safeTransfer(
                IRillaIndex(rillaIndex).feeAddress(),
                amount
            );
            return amount;
        }

        uint256 usdcPrevBal = IERC20(usdc).balanceOf(address(this));
        // execute swap, ensure usdc is the 'to' token
        executeSwap0x(token, amount, swapCallData);

        uint256 usdcCurBal = IERC20(usdc).balanceOf(address(this));
        require(usdcCurBal - usdcPrevBal > 0, "0x route invalid");
        IERC20(usdc).safeTransfer(
            IRillaIndex(rillaIndex).feeAddress(),
            usdcCurBal - usdcPrevBal
        );
        return usdcCurBal - usdcPrevBal;
    }

    // =======================================================================
    // ============================= FETCHING ================================
    // =======================================================================

    /// @notice Helper for active donations
    /// @dev only returns last 50 at most
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

    /// @notice Helper for active member changes
    /// @dev only fetches last 50 max
    function fetchActiveMemberChanges()
        external
        view
        returns (ViewMemberVotes[] memory, uint256)
    {
        uint256 length = memberChanges.length;
        ViewMemberVotes[] memory votes = new ViewMemberVotes[](length);
        uint256 head = 0;
        bool lenOver50 = length > 50;
        for (uint256 i = length - 1; lenOver50 ? i > length - 50 : i > 0; --i) {
            // only grab last 50 max
            uint256 idx = i - 1;
            if (isVoteActive(idx, VoteType.MEMBERCHANGE)) {
                ViewMemberVotes memory vote = votes[head];
                vote.id = idx;
                vote.add = memberChanges[idx].add;
                vote.finalized = memberChanges[idx].finalized;
                vote.members = memberChanges[idx].members;
                head++;
            }
        }
        return (votes, head);
    }

    /// @notice Helper for active swaps
    /// @dev only fetches last 50 max
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

    /// @notice returns donations length (highest id)
    function getDonationsLength() external view returns (uint256) {
        return donations.length;
    }

    /// @notice returns memberChanges length (highest id)
    function getMemberChangesLength() external view returns (uint256) {
        return memberChanges.length;
    }

    /// @notice returns swaps length (highest id)
    function getSwapsLength() external view returns (uint256) {
        return swaps.length;
    }

    // =========================================================
    // =========== EVENTS, MODIFIERS, AND STRUCTS  =============
    // =========================================================
    event DonationIn(address token, uint256 amount);
    event DonationOut(uint256 amount, uint32 EIN);
    event DafSwap(address from, address to, uint256 amount);
    event MemberVoteCreation(
        address creator,
        address[] members,
        bool addOrRemove
    );
    event MembersChanged(address[] modified, bool addOrRemove);

    modifier onlyDafMember() {
        bool isMember = false;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == msg.sender) {
                isMember = true;
                break;
            }
        }
        require(isMember, "Sender is not a member of this DAF.");
        _;
    }

    modifier onlyUnfinalizedVote(uint256 id, VoteType voteType) {
        require(
            voteType == VoteType.DONATION
                ? !donations[id].finalized
                : voteType == VoteType.MEMBERCHANGE
                ? !memberChanges[id].finalized
                : !swaps[id].finalized,
            "Vote already finalized"
        );
        require(isVoteActive(id, voteType), "Vote is not active");
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

    modifier onlyWhenUnpaused() {
        require(!IRillaIndex(rillaIndex).isPaused(), "Contract is paused");
        _;
    }

    struct Donation {
        uint64 createTime;
        bool finalized;
        uint256 amount;
        uint32 EIN;
        mapping(address => int256) votes;
    }

    struct MemberChange {
        uint64 createTime;
        bool finalized;
        bool add;
        address[] members;
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

    struct ViewDonations {
        uint256 id;
        uint256 amount;
        uint32 EIN;
        uint64 createTime;
        bool finalized;
    }

    struct ViewMemberVotes {
        uint256 id;
        bool add;
        bool finalized;
        address[] members;
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
}
