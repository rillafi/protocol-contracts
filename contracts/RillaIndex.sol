// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

interface IDaf {
    function initialize(address, string memory, address[] memory) external;
}

contract RillaIndex is Ownable {
    modifier onlyDaf() {
        require(DAFs[msg.sender] > 0, "Address is not a DAF.");
        _;
    }
    // modifier onlyFactory() {
    //     require(
    //         msg.sender == dafFactoryAddress,
    //         "Txn sender must be the DAF Factory."
    //     );
    //     _;
    // }

    struct CharityInfo {
        uint32 EIN;
        string name;
    }
    struct CharityDonation {
        uint64 dafId;
        uint64 charityId;
        bool fulfilled;
        uint256 amount;
    }

    // ======================================================
    // ================ DECLARE STATE VARIABLES =============
    // ======================================================
    CharityInfo[] public charities; // index is charityId
    CharityDonation[] public donations; // index is donationId
    mapping(address => uint256) public DAFs; // address of DAF with respective ID
    mapping(address => address[]) public ownersDAFs; // address of user maps to all DAFs they are an owner of. Remove by copying last element to empty location, then pop last element.
    uint256 public numUnfulfilled; // number of donations where fulfilled is false
    uint256 public numDAFs;
    // address public dafFactoryAddress;
    address public dafImplementation;
    address public feeAddress;
    uint256 public feePercent;
    uint256 versionCount;

    constructor(address _dafImplementation) {
        dafImplementation = _dafImplementation;
    }

    // ======================================================
    // ================   CHARITY FUNCTIONS     =============
    // ======================================================
    function getCharityFromId(uint256 charityId)
        public
        view
        returns (CharityInfo memory)
    {
        return charities[charityId];
    }

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

    function addCharity(uint32 EIN, string calldata name) public onlyOwner {
        charities.push(CharityInfo(EIN, name));
    }

    /// @notice Logs donation. Emits amount, charityinfo, and donationId.
    /// @dev Explain to a developer any extra details
    /// @param amount Amount of UDSC donated
    /// @param charity CharityInfo struct
    /// @param donationId ID of donation
    event NewDonation(uint256 amount, CharityInfo charity, uint256 donationId);

    function createDonation(uint256 amount) public onlyDaf {
        numUnfulfilled++;
        // TODO: add donation to donation
        // TODO: send USDC from DAF to fiat fulfillment address

        emit NewDonation(amount, charities[0], numDAFs);
    }

    // ======================================================
    // ================      DAF FUNCTIONS      =============
    // ======================================================
    event NewDaf(address newDafAddress, uint256 dafId, string name);

    /// @notice Factory for new DAFs. Creates new Proxy that points to DAF implementation, then logs address.
    /// @param name Name of new DAF.
    function makeDaf(
        string calldata name,
        address[] calldata _owners
    ) public returns (address account) {
        account = Clones.clone(dafImplementation);
        IDaf(account).initialize(address(this), name, _owners);
        DAFs[account] = ++numDAFs; // dafId
        for (uint256 i = 0; i < _owners.length; i++) {
            ownersDAFs[_owners[i]].push(account); // add owner to account array
        }
        emit NewDaf(account, numDAFs, name);
    }

    function getFeeAddress() external view returns (address) {
        return feeAddress;
    }

    function getFeePercent() external view returns (uint256) {
        return feePercent;
    }

    /// @notice Returns array of all DAF addresses that owner is part owner of
    /// @param owner Address of owner that is mapping key
    /// @return Array of all DAF addresses that owner owns
    function getDAFsForOwner(address owner) external view returns (address[] memory) {
        return ownersDAFs[owner];
    }
}

// TODO: Figure out how to be a factory. Create proxy implementation that points to a implementation.
