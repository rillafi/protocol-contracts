import { ethers } from "hardhat";
import { Signer } from "ethers";
import { deploy } from "../scripts/deploy";
import hre from "hardhat";

hre.run("compile").then(() => {
  describe("Full Deploy", function () {
    let accounts: Signer[];

    beforeEach(async function () {
      await deploy();
      accounts = await ethers.getSigners();
    });

    it("should deploy contracts", async function () {
      // Do something with the accounts
      // load token contract
      const Token = await ethers.getContractFactory("Sch0lar");
      // deploy token contract
      const token = await Token.deploy();
      await token.wait();
      // load Sch0larIndex contract
      const Sch0larIndex = await ethers.getContractFactory("Sch0larIndex");
      // deploy Sch0larIndex contract
      const scholarIndex = await Sch0larIndex.deploy();
      await scholarIndex.wait();
    });
  });
});
