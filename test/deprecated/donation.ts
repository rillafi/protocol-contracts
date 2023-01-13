import fetch from 'node-fetch'
import hre, { ethers } from 'hardhat'
import { Signer, Contract } from 'ethers'
import { expect } from 'chai'
import erc20abi from '../abis/erc20abi.json'
import routerabi from '../abis/velodrome/router.json'
import Zeroxabi from '../abis/0x.json'
import tokenList from '../tools/tokenList.json'

function delay(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time))
}

describe('Donation Contract', function () {
  const MAXTIME = 4 * 365 * 86400

  let donationRouter: Contract
  let router: Contract
  let dai: Contract
  let usdc: Contract
  let accounts: Signer[]
  let addys: String[]
  let deployer
  let user: Signer
  let depAdd: String
  let userAdd: String
  let depositor: Signer
  let depositorAdd: String
  let feeAdd: String
  let charityAdd: String
  let charityBal: number = 0
  let feeBal: number = 0
  const wethAdd = '0x4200000000000000000000000000000000000006'
  const zeroxAdd = '0xDEF1ABE32c034e558Cdd535791643C58a13aCC10'
  const MAXUINT = ethers.constants.MaxUint256

  async function checkBalances() {
    const newFeeBal = Number(
      ethers.utils.formatUnits(await usdc.balanceOf(feeAdd), 6)
    )
    const newCharityBal = Number(
      ethers.utils.formatUnits(await usdc.balanceOf(charityAdd), 6)
    )
    expect(newFeeBal).to.be.greaterThan(feeBal)
    expect(newCharityBal).to.be.greaterThan(charityBal)
    expect(newCharityBal).to.be.greaterThan(newFeeBal)
    console.log(`Charity Balance +=${newCharityBal - charityBal}`)
    console.log(`Fee Balance +=${newFeeBal - feeBal}`)
    feeBal = newFeeBal
    charityBal = newCharityBal
  }

  before(async function () {
    router = await ethers.getContractAt(
      routerabi,
      '0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9'
    )
    dai = await ethers.getContractAt(
      erc20abi,
      '0xda10009cbd5d07dd0cecc66161fc93d7c9000da1'
    )
    usdc = await ethers.getContractAt(
      erc20abi,
      '0x7f5c764cbc14f9669b88837ca1490cca17c31607'
    )

    // await deploy();
    accounts = await ethers.getSigners()
    addys = await Promise.all(accounts.map((acc) => acc.getAddress()))
    deployer = accounts[0]
    user = accounts[1]
    depAdd = addys[0]
    userAdd = addys[1]
    feeAdd = addys[10]
    charityAdd = addys[11]

    const accountToImpersonate = '0xa3f45e619cE3AAe2Fa5f8244439a66B203b78bCc'
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [accountToImpersonate],
    })
    // await helpers.impersonateAccount(accountToImpersonate);
    depositor = await ethers.getSigner(accountToImpersonate)
    depositorAdd = await depositor.getAddress()
    const DonationRouter = await ethers.getContractFactory('DonationRouter')
    donationRouter = await DonationRouter.deploy(
      charityAdd,
      feeAdd,
      '5000',
      usdc.address,
      wethAdd,
      zeroxAdd
    )
  })

  it('Donates USDC', async function () {
    let tx = await usdc
      .connect(depositor)
      .approve(donationRouter.address, MAXUINT)
    await tx.wait()
    tx = await donationRouter
      .connect(depositor)
      .donate(usdc.address, '1000000000', '0x')
    await tx.wait()
    checkBalances()
  })

  it('Donates DAI', async function () {
    const usdc2daiRoute = [
      {
        from: usdc.address,
        to: dai.address,
        stable: true,
      },
    ]
    let tx = await usdc.connect(depositor).approve(router.address, MAXUINT)
    await tx.wait()
    tx = await router
      .connect(depositor)
      .swapExactTokensForTokens(
        '1000000' + '0'.repeat(6),
        0,
        usdc2daiRoute,
        depositorAdd,
        Math.floor(Date.now() / 1000) + 100
      )
    await tx.wait()
    tx = await dai.connect(depositor).approve(donationRouter.address, MAXUINT)
    await tx.wait()
    let daiBal = await dai.balanceOf(depositorAdd)
    const swapAmount = daiBal.div(10)
    const quoteUrl = `https://optimism.api.0x.org/swap/v1/quote?sellAmount=${swapAmount.toString()}&buyToken=USDC&sellToken=DAI`
    const res = await fetch(quoteUrl)
    const quote = await res.json()
    const zerox = await ethers.getContractAt(Zeroxabi, quote.to)
    tx = await donationRouter
      .connect(depositor)
      .donate(dai.address, swapAmount, quote.data)
    await tx.wait()
    checkBalances()
  })

  it('Donates Eth', async function () {
    const ethBal = await depositor.getBalance()
    const swapAmount = ethBal.div(10)
    const quoteUrl = `https://optimism.api.0x.org/swap/v1/quote?sellAmount=${swapAmount.toString()}&buyToken=USDC&sellToken=ETH`
    const res = await fetch(quoteUrl)
    const quote = await res.json()
    let tx = await donationRouter
      .connect(depositor)
      .donate(wethAdd, swapAmount, quote.data, { value: swapAmount })
    await tx.wait()
    checkBalances()
  })

  it('Only allows USDC end token', async function () {
    let daiBal = await dai.balanceOf(depositorAdd)
    const swapAmount = daiBal.div(10)
    const quoteUrl = `https://optimism.api.0x.org/swap/v1/quote?sellAmount=${swapAmount.toString()}&buyToken=0x4200000000000000000000000000000000000042&sellToken=DAI`
    const res = await fetch(quoteUrl)
    const quote = await res.json()
    await expect(
      donationRouter
        .connect(depositor)
        .donate(dai.address, swapAmount, quote.data)
    ).to.be.reverted
  })

  it('Processes txn like in the app', async function () {
    let daiBal = await dai.balanceOf(depositorAdd)
    const swapAmount = daiBal.div(10)
    function createQueryString(obj: any) {
      let str = ''
      let count = 0
      for (const key of Object.keys(obj)) {
        if (count > 0) {
          str += '&'
        }
        str += `${key}=${obj[key]}`
        count += 1
      }
      return str
    }
    const input = 'DAI'
    const chainId = 10 // ethers.provider.network.chainId
    const quoteUrlBase0x = { 10: 'https://optimism.api.0x.org/swap/v1/quote' }
    const token = tokenList.filter(
      (elem) => elem.chainId == 10 && elem.symbol == input
    )[0]
    const queryString = createQueryString({
      sellAmount: swapAmount.toString(),
      buyToken: 'USDC',
      sellToken: token.address,
    })
    const quoteUrl = `${quoteUrlBase0x[chainId]}?${queryString}`
    const res = await fetch(quoteUrl)
    const quote = await res.json()
    let tx = await donationRouter
      .connect(depositor)
      .donate(dai.address, swapAmount, quote.data)
    await tx.wait()
    checkBalances()
  })
})
