import hre, { ethers } from "hardhat";
import { Signer, Contract } from "ethers";
import { expect } from "chai";
import erc20abi from "../abis/erc20abi.json";
import routerabi from "../abis/velodrome/router.json";
import helpers from "@nomicfoundation/hardhat-network-helpers";

function delay(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time));
}

describe("Optimism fork", function () {
  const MAXTIME = 4 * 365 * 86400;

  let rillaVault: Contract;
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
    const accountToImpersonate = "0xa3f45e619cE3AAe2Fa5f8244439a66B203b78bCc";
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [accountToImpersonate],
    });
    // await helpers.impersonateAccount(accountToImpersonate);
    depositor = await ethers.getSigner(accountToImpersonate);
    depositorAdd = await depositor.getAddress();
    const Vault = await ethers.getContractFactory("rillaVelodromeVault");
    // address _asset,
    // string memory _name,
    // string memory _symbol,
    // address _yieldSource,
    // uint256 _feePercent,
    // address _feeAddress,
    // address _adminAddress,
    // address _veloGauge,
    // address _rewardToken,
    // IVeloRouter.route[] memory _routeFeeToken
    const veloRoute = [
      {
        from: "0x3c8b650257cfb5f272f799f5e2b4e65093a11a05",
        to: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
        stable: false,
      },
    ];

    rillaVault = await Vault.deploy(
      "0x4f7ebc19844259386dbddb7b2eb759eefc6f8353",
      "Rilla Standard Velodrome sAMM-USDC/DAI",
      "rillaSVeloUSDC/DAI",
      ethers.BigNumber.from("15000"),
      depAdd,
      userAdd,
      "0xc4ff55a961bc04b880e60219ccbbdd139c6451a4",
      "0x3c8B650257cFb5f272f799F5e2b4e65093a11a05",
      veloRoute
    );
  });

  it("deploys", async function () {
    // console.log(vault.address);
  });

  it("Deposits USDC and DAI into Liquidity Pool", async function () {
    const usdc2daiRoute = [
      {
        from: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
        to: "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1",
        stable: true,
      },
    ];
    const dai2usdcRoute = [
      {
        from: "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1",
        to: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
        stable: true,
      },
    ];
    let tx = await usdc.connect(depositor).approve(router.address, MAXUINT);
    await tx.wait();
    tx = await dai.connect(depositor).approve(router.address, MAXUINT);
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
    let quoteSwap = await router.getAmountsOut(daiBal, dai2usdcRoute);
    console.log(quoteSwap);
    let quote = await router.quoteAddLiquidity(
      usdc.address,
      dai.address,
      true,
      quoteSwap[1],
      daiBal
    );
    console.log(quote);
    tx = await router
      .connect(depositor)
      .addLiquidity(
        usdc.address,
        dai.address,
        true,
        quote.amountA,
        quote.amountB,
        0,
        0,
        depositorAdd,
        Math.floor(Date.now() / 1000) + 100
      );
    await tx.wait();
  });

  it("Allows Deposit into Rilla Vault", async function () {
    const veloPair = await ethers.getContractAt(
      erc20abi,
      await router.pairFor(usdc.address, dai.address, true)
    );
    let tx = await veloPair
      .connect(depositor)
      .approve(rillaVault.address, MAXUINT);
    await tx.wait();
    // console.log(veloPair.address);
    // console.log(await veloPair.allowance(depositor, veloPair.address));
    // console.log(await veloPair.balanceOf(depositorAdd));

    tx = await rillaVault
      .connect(depositor)
      .deposit(await veloPair.balanceOf(depositorAdd), depositorAdd);
    await tx.wait();
  });
});
