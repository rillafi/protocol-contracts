// import { ethers } from "hardhat";
// import { Signer } from "ethers";
// import { deploy } from "../scripts/deploy";
// import hre from "hardhat";

// hre.run("compile").then(() => {
//   describe("Full Deploy", function () {
//     let accounts: Signer[];

//     beforeEach(async function () {
//       await deploy();
//       accounts = await ethers.getSigners();
//     });

//     it("should deploy contracts", async function () {
//       // Do something with the accounts
//       // load token contract
//       const Token = await ethers.getContractFactory("Rilla");
//       // deploy token contract
//       const token = await Token.deploy();
//       await token.wait();
//       // load RillaIndex contract
//       const RillaIndex = await ethers.getContractFactory("RillaIndex");
//       // deploy RillaIndex contract
//       const scholarIndex = await RillaIndex.deploy();
//       await scholarIndex.wait();
//     });
//   });
// });
