import hre, { ethers } from "hardhat";

async function main() {
  // if (hre.network.config.chainId !== 31337) return;
  console.log(
    await ethers.provider.getCode("0x0165878A594ca255338adfa4d48449f69242Eb8F")
  );
  const ve = require("../deployedContracts/31337/veRILLA.json");
  const contract = await ethers.getContractAt(ve.abi, ve.address);
  console.log(contract);
  console.log(
    await contract["balanceOf(address)"](
      "0x0165878A594ca255338adfa4d48449f69242Eb8F"
    )
  );
  console.log(
    await contract.locked("0x0165878A594ca255338adfa4d48449f69242Eb8F")
  );
}

main();
