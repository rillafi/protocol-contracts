// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

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
    CharityDonation[] public donations; // index is donationId
    mapping(uint256 => bool) public charities; // EIN mapping to name
    mapping(address => uint256) public DAFs; // address of DAF with respective ID
    mapping(address => address[]) public ownersDAFs; // address of user maps to all DAFs they are an owner of. Remove by copying last element to empty location, then pop last element.
    uint256 public numUnfulfilled; // number of donations where fulfilled is false
    uint256 public numDAFs;
    // state vars with setters
    address public dafImplementation;
    address public veRilla;
    address public feeAddress;
    uint256 public feeOutBps = 100;
    uint256 public feeInBps = 100;
    uint256 public waitTime = 1 weeks;
    uint256 public interimWaitTime = 1 days;
    uint256 public expireTime = 3 weeks;
    uint256 public rillaVoteMin = 1000e18;

    constructor(
        address _dafImplementation,
        address _veRilla,
        address _feeAddress
    ) {
        dafImplementation = _dafImplementation;
        feeAddress = _feeAddress;
        veRilla = _veRilla;
    }

    // ======================================================
    // ================   CHARITY FUNCTIONS     =============
    // ======================================================

    function getDonationFromId(uint256 donationId)
        public
        view
        returns (CharityDonation memory)
    {
        return donations[donationId];
    }

    function getUnfulfilledDonations(uint256)
        public
        view
        returns (CharityDonation[] memory out)
    {
        uint256 found = 0;
        for (
            uint256 i = donations.length - 1;
            numUnfulfilled - found > 0 && i > 0;
            i--
        ) {
            CharityDonation memory donation = donations[i];
            if (!donation.fulfilled) {
                out[found++] = donation;
            }
        }
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

    function fulfillDonation(uint256[] memory donationIds) external onlyOwner {
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

    /// @notice Allows endpoint for other contracts to fetch from. Easier to control.
    /// @return fee address (multisig)
    function getFeeAddress() external view returns (address) {
        return feeAddress;
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

    /// @notice Allows endpoint for other contracts to fetch from. Easier to control.
    /// @return fee percent, max value is 10_000 (1e4)
    function getOutFeeBps() external view returns (uint256) {
        return feeOutBps;
    }

    /// @notice Allows endpoint for other contracts to fetch from. Easier to control.
    /// @return fee percent, max value is 10_000 (1e4)
    function getInFeeBps() external view returns (uint256) {
        return feeInBps;
    }

    function getWaitTime() external view returns (uint256) {
        return waitTime;
    }

    function getInterimWaitTime() external view returns (uint256) {
        return interimWaitTime;
    }


    function getExpireTime() external view returns (uint256) {
        return expireTime;
    }
    function getVoteMin() external view returns (uint256) {
        return rillaVoteMin;
    }

    function getVeRillaAddress() external view returns (address) {
        return veRilla;
    }
    function isAcceptedEIN(uint256 EIN) external view returns (bool) {
        return charities[EIN];
    }

    function setDafImplementation(address _daf) public onlyOwner {
        dafImplementation = _daf;
    }

    function setVeRilla(address _veRilla) public onlyOwner {
        veRilla = _veRilla;
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
    }

    function setFeeOutBps(uint256 _feeOutBps) public onlyOwner {
        feeOutBps = _feeOutBps;
    }

    function setFeeInBps(uint256 _feeInBps) public onlyOwner {
        feeInBps = _feeInBps;
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
