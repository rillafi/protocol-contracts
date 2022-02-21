const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SCLR", function () {
  it("Should increase totalSupply by minting", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const SCLR = await ethers.getContractFactory("SCLR");
    const sclr = await SCLR.deploy();
    await sclr.deployed();

    totalSupply = await sclr.totalSupply()
    expect(Number(ethers.utils.formatUnits(totalSupply))).to.equal(1000000000);
  });
});
