import { DeployedInfo } from "./helpers";
import { DeployedInfoConfig, deployLocal } from "./deployLocal";
import { Contract } from "ethers";
import fs from "fs";
import path from "path";
import hre, { ethers } from "hardhat";

interface DeployedContracts {
  [name: string]: Contract;
}
async function getContracts() {
  let deployedInfo: DeployedInfoConfig = {};
  const contracts: DeployedContracts = {};
  for (const file of fs.readdirSync(
    path.join(__dirname, `../deployedContracts/31337`)
  )) {
    const js: DeployedInfo = require(path.join(
      __dirname,
      `../deployedContracts/31337/${file}`
    ));
    deployedInfo[file.replace(".json", "")] = js;
    contracts[file.replace(".json", "")] = await ethers.getContractAt(
      js.abi,
      js.address
    );
  }
  console.log(Object.keys(contracts));
  return { deployedInfo, contracts };
}
async function configLocal() {
  const accounts = await ethers.getSigners();
  const addys = await Promise.all(accounts.map((acc) => acc.getAddress()));
  const deployer = addys[0];
  const user = addys[1];
  const admin = addys[2];
  const fees = addys[3];
  const { deployedInfo, contracts } = await getContracts();
  await accounts[19].sendTransaction({
    to: "0xC83d823146bdB0Ed119EA55aca30691F2a247E52",
    value: ethers.utils.parseEther("1"),
  });
}
if (typeof require !== "undefined" && require.main === module) {
  deployLocal();
  configLocal();
}
