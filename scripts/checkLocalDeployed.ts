import fs from "fs";
import path from "path";
import { ethers } from "hardhat";

async function checkLocal() {
  const rillaInfo = require("../deployedContracts/31337/RILLA.json");
  const cont = await ethers.getContractAt(
    rillaInfo.abi as any[],
    rillaInfo.address
  );
  console.log(await cont.balanceOf(rillaInfo.address));
}
if (typeof require !== "undefined" && require.main === module) {
  checkLocal();
}
