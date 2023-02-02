import hre, { ethers } from "hardhat";
import fs from "fs";
import path from "path";
import { DeployedInfo, saveDeployedInfo } from "./helpers/helpers";

async function verifyEtherscanAndSave(
  allContracts: string[],
  deployedInfo: DeployedInfo,
  contractName: string,
  constructorArguments: any[]
) {
  const match = allContracts.find((element) => {
    if (element.includes(`${contractName}.sol`)) {
      return true;
    }
  });
  try {
    await hre.run("verify:verify", {
      address: deployedInfo.address,
      constructorArguments,
      contract: `${match?.substring(
        1 + match?.indexOf("/contracts/")
      )}:${contractName}`,
    });
    deployedInfo.verified = true;
    saveDeployedInfo(deployedInfo, contractName);
  } catch (e: any) {
    if (e._isHardhatPluginError && e._isNomicLabsHardhatPluginError) {
      const chain = deployedInfo.network.chainId;
      console.log(
        "There was an error from Hardhat, the contract is likely already verified. Check manually and then manually change verified to true at " +
          path.join(
            __dirname,
            `../deployed_contracts/${chain}/${contractName}.json`
          )
      );
      console.dir(e);
    } else {
      console.log(e);
      console.dir(e);
    }
  }
}

async function main() {
  /* const chains = fs.readdirSync(path.join(__dirname, "../deployed_contracts")); */
  /* const allContracts = getAllFiles(path.join(__dirname, "../contracts"), []); */
  /* for (const chain of chains) { */
  /*   if (chain === "31337") continue; */
  /*   const contracts = fs.readdirSync( */
  /*     path.join(__dirname, `../deployed_contracts/${chain}`) */
  /*   ); */
  /*   for (const contract of contracts) { */
  /*     const contractName = contract.replace(".json", ""); */
  /*     const deployedInfo: DeployedInfo = JSON.parse( */
  /*       fs */
  /*         .readFileSync( */
  /*           path.join( */
  /*             __dirname, */
  /*             `../deployed_contracts/${chain}/${contractName}.json` */
  /*           ) */
  /*         ) */
  /*         .toString() */
  /*     ); */
  /*     if (!deployedInfo.verified) { */
  /*       if (hre.network.name !== deployedInfo.network.name) */
  /*         hre.changeNetwork(deployedInfo.network.name); */
  /*       console.log(deployedInfo.address); */
  /*       await verifyEtherscanAndSave( */
  /*         allContracts, */
  /*         deployedInfo, */
  /*         contractName, */
  /*         deployedInfo.constructorArguments */
  /*       ); */
  /*     } */
  /*   } */
  /* } */
  /* process.exit(0); */
    await hre.run("verify:verify", {
      address: "",
      constructorArguments: "0x96D17e1301b31556e5e263389583A9331e6749E9",
      contract: "TokenVesting",
    });
}

main();
