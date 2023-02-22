/* import fs from 'fs'; */
/* import path from 'path'; */
import fetch from 'node-fetch';
import _ from 'lodash';
/* import { objectInArray } from '../scripts/helpers/helpers'; */

/* async function getVelodromeTokenList() { */
/*     const res = await fetch('https://api.velodrome.finance/api/v1/pairs'); */
/*     const list = (await res.json()).data as any[]; */
/*     const tokenList: any[] = []; */
/**/
/*     for (const pair of list) { */
/*         if (!objectInArray(pair.token0, tokenList)) { */
/*             tokenList.push(pair.token0); */
/*         } */
/*         if (!objectInArray(pair.token1, tokenList)) { */
/*             tokenList.push(pair.token1); */
/*         } */
/*     } */
/*     tokenList.forEach((_, i) => { */
/*         tokenList[i].chainId = 10; */
/*     }); */
/*     return tokenList; */
/* } */
/**/
/* async function getOptimismTokenList() { */
/*     const res = await fetch( */
/*         'https://raw.githubusercontent.com/ethereum-optimism/ethereum-optimism.github.io/master/optimism.tokenlist.json' */
/*     ); */
/*     const list = (await res.json()).tokens; */
/*     const tokenList: any[] = []; */
/**/
/*     for (const elem of list) { */
/*         if (elem.chainId == 10) { */
/*             tokenList.push(elem); */
/*         } */
/*     } */
/*     return tokenList; */
/* } */
/**/
/* function filterList(arr: any[]) { */
/*     arr = arr.filter((elem) => elem.logoURI); */
/*     arr.forEach((elem, i) => { */
/*         if (Object.keys(elem).includes('extensions')) { */
/*             delete elem.extensions; */
/*             arr[i] = elem; */
/*         } */
/*         arr[i].address = elem.address.toLowerCase(); */
/*     }); */
/*     _.map(arr, function (o, i) { */
/*         var eq = _.find(arr, function (e, ind) { */
/*             if (i > Number(ind)) { */
/*                 return _.isEqual(e, o); */
/*             } */
/*         }); */
/*         if (eq) { */
/*             o.isDuplicate = true; */
/*             return o; */
/*         } else { */
/*             return o; */
/*         } */
/*     }); */
/*     arr.forEach((elem, i) => { */
/*         if (arr[i].isDuplicate) { */
/*             arr.splice(i); */
/*         } */
/*     }); */
/*     return arr; */
/* } */
/**/
/* async function main() { */
/*     const funcList = [getVelodromeTokenList, getOptimismTokenList]; */
/*     let arr: any[] = []; */
/*     for (const func of funcList) { */
/*         const res = await func(); */
/*         arr = [...arr, ...res]; */
/*     } */
/*     arr = filterList(arr); */
/*     fs.writeFileSync( */
/*         path.join(__dirname, '../tools/tokenList.json'), */
/*         JSON.stringify(arr) */
/*     ); */
/*     return arr; */
/* } */
/**/
async function getVelodromeGauge() {
    const res = await fetch('https://api.velodrome.finance/api/v1/pairs');
    const list = (await res.json()).data as any[];
    console.log(res)

    for (const pair of list) {
        if (pair.symbol == 'vAMM-OP/VELO' || pair.symbol == 'vAMM-VELO/OP') {
            console.log(pair);
        }
    }
}
getVelodromeGauge()
/* main(); */

// in UI, we can reference the same tokenList.json file always but filter by chainId for what the current chainId is
