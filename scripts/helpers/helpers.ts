import fs from "fs";
import path from "path";

export interface DeployedInfo {
  address: string;
  abi: Object;
  network: { chainId: number; name: string };
  verified: boolean;
  deployedTransaction: Object;
  contractName: string;
}

export function saveDeployedInfo(
  deployedInfo: DeployedInfo,
  contractName: string
) {
  if (
    !fs.existsSync(
      path.join(
        __dirname,
        `../../deployed_contracts/${deployedInfo.network.chainId}`
      )
    )
  ) {
    console.log("here");
    fs.mkdirSync(
      path.join(
        __dirname,
        `../../deployed_contracts/${deployedInfo.network.chainId}`
      )
    );
  }
  fs.writeFileSync(
    path.join(
      __dirname,
      `../../deployed_contracts/${deployedInfo.network.chainId}/${contractName}.json`
    ),
    JSON.stringify(deployedInfo)
  );
}
