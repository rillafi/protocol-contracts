import hre, { ethers } from "hardhat";

async function main() {
  // if (hre.network.config.chainId !== 31337) return;
  console.log(
    await ethers.provider.getCode("0xc6aEE74dd8540632faB51a7ebB9d68240669D0Ea"),
    await ethers.provider.getCode("0xb19837Be206624Cc9A6777Cb89E3FDbCf0AE6C15")
  );
}

main();
