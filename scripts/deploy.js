// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const fs = require("fs");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  await hre.run('compile');

  // We get the contract to deploy
  const SCLR = await hre.ethers.getContractFactory("SCLR");
  const sclr = await SCLR.deploy();
  await sclr.deployed();

  // We write the address to the artifacts file that is generated
  const sclr_json = require("../artifacts/contracts/SCLR.sol/SCLR.json");
  sclr_json.address = sclr.address
  fs.writeFileSync("./artifacts/contracts/SCLR.sol/SCLR.json", JSON.stringify(sclr_json))

  console.log("SCLR deployed to:", sclr.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
