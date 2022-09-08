import fetch from "node-fetch";

async function getVelodromePairInfo(
  token0: string,
  token1: string,
  stable: boolean
) {
  const type = stable ? "sAMM" : "vAMM";
  const name0 = `${type}-${token0}/${token1}`;
  const name1 = `${type}-${token1}/${token0}`;
  const res = await fetch("https://api.velodrome.finance/api/v1/pairs");
  const body = await res.json();
  for (const pair of body.data) {
    if (pair.symbol === name0 || pair.symbol === name1) {
      console.log(pair);
      process.exit(0);
    }
  }
}

getVelodromePairInfo("DAI", "USDC", true);
