import dotenv from "dotenv";
import { ethers } from "ethers";

dotenv.config();
console.log(ethers.Wallet.createRandom().mnemonic);

async function main() {
  console.log(
    await ethers.Wallet.fromMnemonic(
      process.env.MNEMONIC as string
    ).getAddress()
  );
}
main();
