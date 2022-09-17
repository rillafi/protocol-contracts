import { ethers, Contract } from "ethers";
import fs from "fs";
import path from "path";

interface DeployedInfo {
  address: string;
  abi: any[];
  network: { chainId: number; name: string };
  verified: boolean;
  deployedTransaction: Object;
  contractName: string;
  constructorArguments: any[];
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

export async function getDeployedInfo(
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

export async function saveContractInfo(
  contract: Contract,
  name: string,
  args: any[],
  saveName: string
) {
  saveDeployedInfo(await getDeployedInfo(contract, name, args), saveName);
}
