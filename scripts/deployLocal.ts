import { OPCONFIG } from './config/opConfig';
import { Contract } from "ethers";
import fs from "fs";
import path from "path";
import hre, { ethers } from "hardhat";

interface DeployedInfo {
  address: string;
  abi: any[];
  network: { chainId: number; name: string };
  verified: boolean;
  deployedTransaction: Object;
  contractName: string;
  constructorArguments: any[];
}

export interface DeployedInfoConfig {
  [contractName: string]: DeployedInfo;
}

function saveDeployedInfo(deployedInfo: DeployedInfo, saveName: string) {
  if (
    !fs.existsSync(
      path.join(
        __dirname,
        `../deployedContracts/${deployedInfo.network.chainId}`
      )
    )
  ) {
    fs.mkdirSync(
      path.join(
        __dirname,
        `../deployedContracts/${deployedInfo.network.chainId}`
      )
    );
  }
  fs.writeFileSync(
    path.join(
      __dirname,
      `../deployedContracts/${deployedInfo.network.chainId}/${saveName}.json`
    ),
    JSON.stringify(deployedInfo)
  );
}

async function getDeployedInfo(
  ethers: any,
  contract: Contract,
  contractName: string,
  constructorArguments: any[]
): Promise<DeployedInfo> {
  return {
    abi: JSON.parse(
      contract.interface.format(ethers.utils.FormatTypes.json) as string
    ),
    deployedTransaction: contract.deployTransaction,
    address: contract.address,
    network: await contract.provider.getNetwork(),
    verified: false,
    contractName: contractName,
    constructorArguments,
  };
}

function getArgs(args: any[], deployedInfo: any) {
  const argCopy = [];
  for (const arg of args) {
    if (typeof arg === "string" || arg instanceof String) {
      if (arg.includes(".") && isNaN(Number(arg))) {
        const splArg = arg.split(".");
        argCopy.push(deployedInfo[splArg[0]][splArg[1]]);
        continue;
      }
    }
    argCopy.push(arg);
  }
  return argCopy;
}

async function deployContract(name: string, args: any[]) {
  const contract = await ethers.getContractFactory(name);
  const gasLimit = (
    await ethers.provider.estimateGas(contract.getDeployTransaction(...args))
  )
    .mul(12)
    .div(10);
  const gasPrice = (await ethers.provider.getGasPrice()).mul(12).div(10);
  const deployed = await contract.deploy(...args, { gasLimit, gasPrice });
  return getDeployedInfo(ethers, deployed, name, args);
}
export async function deployLocal() {
  console.log("deploying");
  const accounts = await ethers.getSigners();
  const addys = await Promise.all(accounts.map((acc) => acc.getAddress()));
  const deployer = addys[0];
  const user = addys[1];
  const admin = addys[2];
  const fees = addys[3];
  const usdc = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607";
  const zeroX = "0xdef1abe32c034e558cdd535791643c58a13acc10";
  const velo = "0x3c8B650257cFb5f272f799F5e2b4e65093a11a05";
  const lpVeloUsdcDai = "0x4f7ebc19844259386dbddb7b2eb759eefc6f8353";
  const gaugeVeloUsdcDai = "0xc4ff55a961bc04b880e60219ccbbdd139c6451a4";
  const veloRouteVeloUsdc = [
    {
      from: "0x3c8b650257cfb5f272f799f5e2b4e65093a11a05",
      to: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
      stable: false,
    },
  ];
  const contractDeployConfigs: {
    name: string;
    args: any[];
    saveName: string;
  }[] = [
    { name: "RILLA", args: [], saveName: "RILLA" },
    {
      name: "VoteEscrow",
      args: ["RILLA.address", "Vote Escrow RILLA", "veRILLA", "1.0"],
      saveName: "veRILLA",
    },
    {
      name: "rillaVelodromeVault",
      args: [
        lpVeloUsdcDai,
        "Rilla Standard Velodrome sAMM-USDC/DAI",
        "rvsAMM-USDC/DAI",
        ethers.utils.parseEther("0.01"),
        fees,
        admin,
        gaugeVeloUsdcDai,
        velo,
        veloRouteVeloUsdc,
      ],
      saveName: "rvsAMM-USDCDAI",
    },
    {
      name: "DonationRouter",
      args: [OPCONFIG.donationFee, OPCONFIG.usdc, OPCONFIG.zeroxProxy],
      saveName: "DonationRouter",
    },
  ];
  let deployedInfo: DeployedInfoConfig = {};
  for (const config of contractDeployConfigs) {
    const args = getArgs(config.args, deployedInfo);
    const deployedConfig = await deployContract(config.name, args);
    deployedInfo[config.name] = deployedConfig;
    saveDeployedInfo(deployedConfig, config.saveName);
  }
}

if (typeof require !== "undefined" && require.main === module) {
  deployLocal();
}
