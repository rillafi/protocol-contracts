const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DigitalIdentity", function () {
  it("Should increase totalSupply by minting", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const DID = await ethers.getContractFactory("DigitalIdentity");
    const did = await DID.deploy();
    await did.deployed();

    await did.connect(addr1).mint();
    expect(await did.totalSupply()).to.equal(1);
  });

  it("Should mint a token starting at 0 to the address", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const DID = await ethers.getContractFactory("DigitalIdentity");
    const did = await DID.deploy();
    await did.deployed();

    await did.connect(addr1).mint();
    expect(await did.ownerOf(0)).to.equal(addr1.address);
  });
});
