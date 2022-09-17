import { saveContractInfo } from "./helpers";
import hre, { ethers } from "hardhat";
import { OPCONFIG } from "./config/opConfig";

async function deploy() {
  const mainnet = false;

  const config = mainnet ? OPCONFIG : OPCONFIG;

  // Load
  const [Rilla, VeRilla, DonationRouter] = await Promise.all([
    ethers.getContractFactory("RILLA"),
    ethers.getContractFactory("VoteEscrow"),
    ethers.getContractFactory("DonationRouter"),
  ]);

  // deploys
  let args: any[] = [];
  const rilla = await Rilla.deploy();
  await saveContractInfo(rilla, "RILLA", [], "RILLA");
  await rilla.deployed();
  console.log("RILLA deployed to: ", rilla.address);

  args = [rilla.address, "Vote Escrow RILLA", "veRILLA", "veRILLA_1.0.0"];
  const veRilla = await VeRilla.deploy(...args);
  await saveContractInfo(veRilla, "veRILLA", args, "veRILLA");
  await veRilla.deployed();
  console.log("veRILLA deployed to: ", veRilla.address);

  args = [config.donationFee, config.usdc, config.zeroxProxy];
  const donationRouter = await DonationRouter.deploy(...args);
  await saveContractInfo(
    donationRouter,
    "DonationRouter",
    args,
    "DonationRouter"
  );
  await donationRouter.deployed();
  console.log("DonationRouter deployed to: ", donationRouter.address);

  // Initialize
  await donationRouter.setAdminAddress(config.adminAddress);
  console.log("Admin Address set");

  await donationRouter.setFeeAddress(config.feeAddress);
  console.log("Fee Address set");

  console.log("Optimism contracts deployed");
}

if (typeof require !== "undefined" && require.main === module) {
  deploy();
}
