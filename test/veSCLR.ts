import { ethers } from "hardhat";
import { Signer, Contract } from "ethers";
import { expect } from "chai";

function delay(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time));
}

describe("veSCLR", function () {
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

    const Token = await ethers.getContractFactory("SCLR");
    token = await Token.deploy();

    const VeToken = await ethers.getContractFactory("VoteEscrow");
    veToken = await VeToken.deploy(
      token.address,
      "Vote Escrowed SCLR",
      "veSCLR",
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

  it("Allows locks", async () => {
    await token.transfer(userAdd, "1" + "0".repeat(18));
    await token
      .connect(user)
      .approve(veToken.address, ethers.constants.MaxUint256);
    await veToken
      .connect(user)
      .create_lock(
        ethers.BigNumber.from("1" + "0".repeat(18)),
        Math.floor(Date.now() / 1000) + MAXTIME
      );
    const Balance = await veToken.functions["balanceOf(address)"](userAdd);
    const balance = Balance[0];
    expect(Number(ethers.utils.formatEther(balance))).to.be.greaterThan(0);
  });

  it("Allows increasing locks", async () => {
    await token.connect(accounts[0]).transfer(userAdd, "1" + "0".repeat(18));
    await veToken
      .connect(accounts[0])
      .deposit_for(userAdd, "1" + "0".repeat(18));
    const Balance = await veToken.functions["balanceOf(address)"](userAdd);
    const balance = Balance[0];
    expect(Number(ethers.utils.formatEther(balance))).to.be.greaterThan(1);
  });
});
