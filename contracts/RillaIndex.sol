// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IDaf {
    function initialize(
        address,
        string memory,
        address[] memory
    ) external;
}

contract RillaIndex is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    modifier onlyDaf() {
        require(DAFs[msg.sender] > 0, "Address is not a DAF.");
        _;
    }

    struct CharityDonation {
        address daf;
        uint64 charityId;
        bool fulfilled;
        uint256 amount;
    }

    // ======================================================
    // ===================== CONSTANTS ======================
    // ======================================================
    address constant usdc = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    uint256 constant BPS = 10000;
    address constant swap0x = 0xDEF1ABE32c034e558Cdd535791643C58a13aCC10;

    // ======================================================
    // ================ DECLARE STATE VARIABLES =============
    // ======================================================

    CharityDonation[] public donations;
    mapping(uint256 => bool) public charities;
    mapping(address => uint256) public DAFs;
    mapping(address => address[]) public membersDAFs;
    uint256 public numUnfulfilled;
    uint256 public numDAFs;
    // state vars with setters
    bool public isRillaSwapLive;
    bool public paused;
    address public dafImplementation;
    address public rilla;
    address public treasury;
    address public feeAddress;
    uint256 public feeOutBps;
    uint256 public feeInBps;
    uint256 public feeSwapBps;
    uint256 public rillaSwapRate; // 1e12 == 1 USDC / RILLA
    uint256 public waitTime;
    uint256 public interimWaitTime;
    uint256 public expireTime;
    uint256 public rillaVoteMin;

    function initialize(
        address _dafImplementation,
        address _rilla,
        address _feeAddress,
        address _treasury,
        uint256 _rillaSwapRate
    ) public initializer {
        dafImplementation = _dafImplementation;
        rilla = _rilla;
        feeAddress = _feeAddress;
        treasury = _treasury;
        rillaSwapRate = _rillaSwapRate;
        isRillaSwapLive = true;
        feeOutBps = 100;
        feeInBps = 100;
        feeSwapBps = 100;
        waitTime = 1 weeks;
        interimWaitTime = 1 days;
        expireTime = 3 weeks;
        rillaVoteMin = 1000e18;
        paused = false;
        __Ownable_init();
    }

    // ======================================================
    // ================   CHARITY FUNCTIONS     =============
    // ======================================================

    function nDonations() public view returns (uint256) {
        return donations.length;
    }

    function getUnfulfilledDonations()
        public
        view
        returns (CharityDonation[] memory, uint256[] memory)
    {
        CharityDonation[] memory outVals = new CharityDonation[](
            numUnfulfilled
        );
        uint256[] memory outIdxs = new uint256[](numUnfulfilled);
        uint256 found = 0;
        for (
            uint256 i = donations.length;
            numUnfulfilled - found > 0 && i > 0;
            i--
        ) {
            CharityDonation memory donation = donations[i - 1];
            if (!donation.fulfilled) {
                outVals[found] = donation;
                outIdxs[found] = i - 1;
                found++;
            }
        }
        return (outVals, outIdxs);
    }

    function modifyCharities(uint32[] calldata EIN, bool[] calldata state)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < EIN.length; ++i) {
            charities[EIN[i]] = state[i];
        }
    }

    /// @notice Logs donation. Emits amount, charityinfo, and donationId.
    /// @dev Explain to a developer any extra details
    /// @param amount Amount of UDSC donated
    /// @param EIN EIN of organization
    /// @param donationId ID of donation
    event NewDonation(uint256 amount, uint256 EIN, uint256 donationId);

    function createDonation(uint256 amount, uint256 EIN) external onlyDaf {
        numUnfulfilled++;
        CharityDonation storage donation = donations.push();
        donation.daf = msg.sender;
        donation.charityId = uint64(EIN);
        donation.fulfilled = false;
        donation.amount = amount;

        emit NewDonation(amount, EIN, donations.length - 1);
    }

    function fulfillDonations(uint256[] memory donationIds) external onlyOwner {
        for (uint256 i = 0; i < donationIds.length; ++i) {
            CharityDonation storage donation = donations[donationIds[i]];
            donation.fulfilled = true;
            IERC20(usdc).safeTransfer(msg.sender, donation.amount);
            numUnfulfilled--;
        }
    }

    // ======================================================
    // ================      DAF FUNCTIONS      =============
    // ======================================================
    event NewDaf(address newDafAddress, uint256 dafId, string name);

    /// @notice Factory for new DAFs. Creates new Proxy that points to DAF implementation, then logs address.
    /// @param name Name of new DAF.
    function makeDaf(string calldata name, address[] calldata _members)
        public
        returns (address account)
    {
        account = Clones.clone(dafImplementation);
        IDaf(account).initialize(address(this), name, _members);
        DAFs[account] = ++numDAFs; // dafId
        for (uint256 i = 0; i < _members.length; i++) {
            membersDAFs[_members[i]].push(account); // add member to account array
        }
        emit NewDaf(account, numDAFs, name);
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

    function rillaFee(
        address token,
        uint256 amount,
        bytes calldata swapCallData
    ) external onlyDaf returns (uint256 rillaAmount) {
        if (isRillaSwapLive) {
            amount = (amount * feeInBps) / BPS;
            if (token == usdc) {
                IERC20(usdc).safeTransferFrom(msg.sender, feeAddress, amount);
                rillaAmount = rillaSwapRate * (amount);
                IERC20(rilla).safeTransferFrom(
                    treasury,
                    msg.sender,
                    rillaAmount
                );
                return rillaAmount;
            }
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            uint256 prevBal = IERC20(usdc).balanceOf(address(this));
            // execute swap, ensure usdc is the 'to' token
            executeSwap0x(token, amount, swapCallData);
            uint256 curBal = IERC20(usdc).balanceOf(address(this));
            require(curBal > prevBal, "Swap route invalid");
            IERC20(usdc).safeTransfer(feeAddress, curBal - prevBal);
            rillaAmount = rillaSwapRate * (curBal - prevBal);
            IERC20(rilla).safeTransferFrom(treasury, msg.sender, rillaAmount);
        }
        // if (isRillaSwapLive) {
        //     // calculate fee
        //     amount = (amount * feeInBps) / BPS;
        //
        //     // pull only the fee amount from the DAF
        //     IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        //
        //     // execute swap, ensure RILLA is the 'to' token
        //     uint256 prevBal = IERC20(rilla).balanceOf(address(this));
        //     executeSwap0x(token, amount, swapCallData);
        //     uint256 curBal = IERC20(rilla).balanceOf(address(this));
        //     require(curBal > prevBal, "Swap route invalid");
        //
        //     IERC20(rilla).safeTransferFrom(treasury, msg.sender, curBal - prevBal);
        // }
    }

    /// @notice gets array of all DAF addresses that member is part member of
    /// @param member Address of member that is mapping key
    /// @return Array of all DAF addresses that member owns
    function getDAFsForMember(address member)
        external
        view
        returns (address[] memory)
    {
        return membersDAFs[member];
    }

    function isAcceptedEIN(uint256 EIN) external view returns (bool) {
        return charities[EIN];
    }

    function setDafImplementation(address _daf) public onlyOwner {
        dafImplementation = _daf;
    }

    function setRilla(address _rilla) public onlyOwner {
        rilla = _rilla;
    }

    function setRillaSwapRate(uint256 _rillaSwapRate) public onlyOwner {
        rillaSwapRate = _rillaSwapRate;
    }

    function setRillaSwapLive(bool val) public onlyOwner {
        isRillaSwapLive = val;
    }

    function setPaused(bool val) public onlyOwner {
        paused = val;
    }

    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
    }

    function setFeeOutBps(uint256 _feeOutBps) public onlyOwner {
        require(_feeOutBps <= 10000);
        feeOutBps = _feeOutBps;
    }

    function setFeeInBps(uint256 _feeInBps) public onlyOwner {
        require(_feeInBps <= 10000);
        feeInBps = _feeInBps;
    }

    function setFeeSwapBps(uint256 _feeSwapBps) public onlyOwner {
        require(_feeSwapBps <= 10000);
        feeSwapBps = _feeSwapBps;
    }

    function setWaitTime(uint256 _waitTime) public onlyOwner {
        waitTime = _waitTime;
    }

    function setInterimWaitTime(uint256 _interimWaitTime) public onlyOwner {
        interimWaitTime = _interimWaitTime;
    }

    function setExpireTime(uint256 _time) public onlyOwner {
        expireTime = _time;
    }

    function setRillaVoteMin(uint256 _rillaVoteMin) public onlyOwner {
        rillaVoteMin = _rillaVoteMin;
    }

    function isPaused() public view returns (bool) {
        return paused;
    }
}
