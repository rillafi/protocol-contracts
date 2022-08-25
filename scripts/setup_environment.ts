import hre, { ethers } from "hardhat";

async function main() {
  // console.log(hre.network.config.chainId);
  // if (hre.network.config.chainId !== 31337) return;
  const signers = await ethers.getSigners();
  const accounts = await signers.map(
    async (signer) => await signer.getAddress()
  );

  const usdc = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607";
  const weth = "0x4200000000000000000000000000000000000006";
  const zerox = "0xdef1abe32c034e558cdd535791643c58a13acc10";
  const config: any = {};
  const deployContracts = [
    { name: "TokenFetch", args: [] },
    {
      name: "DonationRouter",
      args: [accounts[10], accounts[11], "5000", usdc, weth, zerox],
    },
  ];
  for (const contractInfo of deployContracts) {
    const Contract = await ethers.getContractFactory(contractInfo.name);
    const contract = await Contract.deploy(...contractInfo.args);
    config[contractInfo.name] = contract.address;
  }
  console.dir(config);
}

main();
