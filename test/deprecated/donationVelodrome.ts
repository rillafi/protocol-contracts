import fetch from "node-fetch";
import hre, { ethers } from "hardhat";
import { Signer, Contract } from "ethers";
import { expect } from "chai";
import erc20abi from "../abis/erc20abi.json";
import routerabi from "../abis/velodrome/router.json";
import Zeroxabi from "../abis/0x.json";

function delay(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time));
}

describe("Donation Contract", function () {
  const MAXTIME = 4 * 365 * 86400;

  let donationRouter: Contract;
  let router: Contract;
  let dai: Contract;
  let usdc: Contract;
  let accounts: Signer[];
  let addys: String[];
  let deployer;
  let user: Signer;
  let depAdd: String;
  let userAdd: String;
  let depositor: Signer;
  let depositorAdd: String;
  let feeAdd: String;
  let charityAdd: String;
  const wethAdd = "0x4200000000000000000000000000000000000006";
  const usdcAdd = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607";
  const daiAdd = "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1";
  const MAXUINT = ethers.constants.MaxUint256;
  before(async function () {
    router = await ethers.getContractAt(
      routerabi,
      "0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9"
    );
    dai = await ethers.getContractAt(
      erc20abi,
      "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1"
    );
    usdc = await ethers.getContractAt(
      erc20abi,
      "0x7f5c764cbc14f9669b88837ca1490cca17c31607"
    );

    // await deploy();
    accounts = await ethers.getSigners();
    addys = await Promise.all(accounts.map((acc) => acc.getAddress()));
    deployer = accounts[0];
    user = accounts[1];
    depAdd = addys[0];
    userAdd = addys[1];
    feeAdd = addys[10];
    charityAdd = addys[11];

    const accountToImpersonate = "0xa3f45e619cE3AAe2Fa5f8244439a66B203b78bCc";
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [accountToImpersonate],
    });
    // await helpers.impersonateAccount(accountToImpersonate);
    depositor = await ethers.getSigner(accountToImpersonate);
    depositorAdd = await depositor.getAddress();
    const Vault = await ethers.getContractFactory("rillaVelodromeVault");
    const veloRoute = [
      {
        from: wethAdd,
        to: usdcAdd,
        stable: false,
      },
    ];

    const DonationRouter = await ethers.getContractFactory("DonationRouter");
    donationRouter = await DonationRouter.deploy(
      charityAdd,
      feeAdd,
      "5000",
      usdcAdd,
      router.address,
      wethAdd,
      veloRoute
    );
  });

  it("Donates USDC", async function () {
    let tx = await usdc
      .connect(depositor)
      .approve(donationRouter.address, MAXUINT);
    await tx.wait();
    tx = await donationRouter
      .connect(depositor)
      .donate([], usdcAdd, "1000000000", "0");
    await tx.wait();
    const feeBal = Number(
      ethers.utils.formatUnits(await usdc.balanceOf(feeAdd), 6)
    );
    const charityBal = Number(
      ethers.utils.formatUnits(await usdc.balanceOf(charityAdd), 6)
    );
    // console.log(feeBal, charityBal);
    expect(feeBal).to.be.greaterThan(0);
    expect(charityBal).to.be.greaterThan(0);
    expect(charityBal).to.be.greaterThan(feeBal);
  });

  it("Donates DAI", async function () {
    const usdc2daiRoute = [
      {
        from: usdcAdd,
        to: daiAdd,
        stable: true,
      },
    ];
    const dai2usdcRoute = [
      {
        from: daiAdd,
        to: usdcAdd,
        stable: true,
      },
    ];
    let tx = await usdc.connect(depositor).approve(router.address, MAXUINT);
    await tx.wait();
    tx = await router
      .connect(depositor)
      .swapExactTokensForTokens(
        "1000000" + "0".repeat(6),
        0,
        usdc2daiRoute,
        depositorAdd,
        Math.floor(Date.now() / 1000) + 100
      );
    await tx.wait();
    let daiBal = await dai.balanceOf(depositorAdd);
    tx = await dai.connect(depositor).approve(donationRouter.address, MAXUINT);
    await tx.wait();
    const amount = await router.getAmountsOut(daiBal, dai2usdcRoute);
    tx = await donationRouter
      .connect(depositor)
      .donate(
        dai2usdcRoute,
        dai.address,
        daiBal,
        amount[amount.length - 1].mul(99).div(100)
      );
    await tx.wait();
  });

  it("swaps with 0x", async function () {
    console.log(
      await usdc.balanceOf(depositorAdd),
      await dai.balanceOf(depositorAdd)
    );
    const usdcAmount = "1000000000";
    const res = await fetch(
      `https://optimism.api.0x.org/swap/v1/quote?sellAmount=${usdcAmount}&buyToken=DAI&sellToken=USDC`
    );
    const quote = await res.json();
    // const zerox = await ethers.getContractAt(Zeroxabi, data.to);
    dai.connect(depositor).approve(quote.to, MAXUINT);
    console.log(quote.data);
    // let tx = await zerox.transformERC20(data.data);
    let tx = await depositor.sendTransaction(quote);
    await tx.wait();
    console.log(
      await usdc.balanceOf(depositorAdd),
      await dai.balanceOf(depositorAdd)
    );
  });
});
