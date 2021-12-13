//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract DigitalIdentity is ERC721Enumerable, Ownable {
    string baseURI;

    constructor () ERC721("Sch0larDigitalIdentities", "SDID")  {}

    function mint() public {
        _safeMint( msg.sender, totalSupply() );
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseURI = _baseTokenURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
}