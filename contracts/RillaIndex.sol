// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "hardhat/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

interface IDaf {
    function initialize(
        address,
        string memory,
        address[] memory
    ) external;
}

contract RillaIndex is Ownable {
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

    // ======================================================
    // ================ DECLARE STATE VARIABLES =============
    // ======================================================
    CharityDonation[] public donations;
    mapping(uint256 => bool) public charities;
    mapping(address => uint256) public DAFs;
    mapping(address => address[]) public ownersDAFs;
    uint256 public numUnfulfilled;
    uint256 public numDAFs;
    // state vars with setters
    bool public isRillaSwapLive = true;
    address public dafImplementation;
    address public rilla;
    address public treasury;
    address public feeAddress;
    uint256 public feeOutBps = 100;
    uint256 public feeInBps = 100;
    uint256 public feeSwapBps = 100;
    uint256 public rillaSwapRate;
    uint256 public waitTime = 1 weeks;
    uint256 public interimWaitTime = 1 days;
    uint256 public expireTime = 3 weeks;
    uint256 public rillaVoteMin = 1000e18;

    constructor(
        address _dafImplementation,
        address _rilla,
        address _feeAddress,
        address _treasury,
        uint256 _rillaSwapRate
    ) {
        dafImplementation = _dafImplementation;
        feeAddress = _feeAddress;
        rilla = _rilla;
        treasury = _treasury;
        rillaSwapRate = _rillaSwapRate;
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
        CharityDonation[] memory outVals = new CharityDonation[](numUnfulfilled);
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
    function makeDaf(string calldata name, address[] calldata _owners)
        public
        returns (address account)
    {
        account = Clones.clone(dafImplementation);
        IDaf(account).initialize(address(this), name, _owners);
        DAFs[account] = ++numDAFs; // dafId
        for (uint256 i = 0; i < _owners.length; i++) {
            ownersDAFs[_owners[i]].push(account); // add owner to account array
        }
        emit NewDaf(account, numDAFs, name);
    }

    function swapRilla(address sender, uint256 amount) external onlyDaf {
        // only do something if isRillaSwapLive == true
        if (isRillaSwapLive) {
            IERC20(rilla).safeTransferFrom(
                treasury,
                sender,
                amount * rillaSwapRate
            );
        }
    }

    /// @notice gets array of all DAF addresses that owner is part owner of
    /// @param owner Address of owner that is mapping key
    /// @return Array of all DAF addresses that owner owns
    function getDAFsForOwner(address owner)
        external
        view
        returns (address[] memory)
    {
        return ownersDAFs[owner];
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
}
