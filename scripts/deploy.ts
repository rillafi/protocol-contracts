// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

export async function deploy() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  const Token = await ethers.getContractFactory("Sch0lar");
  // deploy token contract
  const token = await Token.deploy();
  await token.wait();
  // load Sch0larIndex contract
  const Sch0larIndex = await ethers.getContractFactory("Sch0larIndex");
  // deploy Sch0larIndex contract
  const scholarIndex = await Sch0larIndex.deploy();
  await scholarIndex.wait();
}
