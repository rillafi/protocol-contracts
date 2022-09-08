import { task } from "hardhat/config";
import deployLocal from "../scripts/deployLocal";

task(
  "deploy:local",
  "deploys a series of contracts to allow testing locally",
  async (taskArgs, hre) => {
    await deployLocal();
  }
);
