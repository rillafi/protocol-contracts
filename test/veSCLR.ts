import { ethers } from "hardhat";
import { Signer, Contract } from "ethers";

describe("VoteEscrow and FeeDistributor Tests", function () {
  let accounts: Signer[];
  let deployer;
  let user;
  let token: Contract;
  let veToken: Contract;
  let feeDist: Contract;

  before(async function () {
    // await deploy();
    accounts = await ethers.getSigners();
    deployer = accounts[0];
    user = accounts[1];

    const Token = await ethers.getContractFactory("SCLR");
    token = await Token.deploy();

    const VeToken = await ethers.getContractFactory("VoteEscrow");
    veToken = await VeToken.deploy(token.address, "veSCLR", "veSCLR", "1.0");

    const FeeDist = await ethers.getContractFactory("FeeDistributor");
    const depAdd = await deployer.getAddress();
    feeDist = await FeeDist.deploy(
      veToken.address,
      Math.floor(Date.now() / 1000),
      token.address,
      depAdd,
      depAdd
    );
  });

  it("should deploy contracts", async function () {
    console.log(veToken.functions);
    console.log(feeDist.functions);
  });
});
