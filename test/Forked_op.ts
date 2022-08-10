import { ethers } from "hardhat";
import { Signer, Contract } from "ethers";
import { expect } from "chai";
import erc20abi from "../abis/erc20abi.json";

function delay(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time));
}

describe("forked mainnet", function () {
  const MAXTIME = 4 * 365 * 86400;

  let accounts: Signer[];
  let addys: String[];
  let deployer;
  let user: Signer;
  let depAdd: String;
  let userAdd: String;
  let token: Contract;
  let veToken: Contract;
  let feeDist: Contract;
  let vesting: Contract;

  before(async function () {
    // await deploy();
    accounts = await ethers.getSigners();
    addys = await Promise.all(accounts.map((acc) => acc.getAddress()));
    deployer = accounts[0];
    user = accounts[1];
    depAdd = addys[0];
    userAdd = addys[1];

    const Token = await ethers.getContractFactory("RILLA");
    token = await Token.deploy();

    const VeToken = await ethers.getContractFactory("VoteEscrow");
    veToken = await VeToken.deploy(
      token.address,
      "Vote Escrowed RILLA",
      "veRILLA",
      "1.0"
    );

    const FeeDist = await ethers.getContractFactory("FeeDistributor");
    feeDist = await FeeDist.deploy(
      veToken.address,
      Math.floor(Date.now() / 1000),
      token.address,
      depAdd,
      depAdd
    );

    const Vesting = await ethers.getContractFactory("TokenVesting");
    vesting = await Vesting.deploy(token.address, veToken.address);
  });

  describe("we are forked", async function () {
    const threecrv = new ethers.Contract(
      "0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490",
      erc20abi,
      accounts[0]
    );
  });
});
