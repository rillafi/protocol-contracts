# Sch0lar Contracts

This project hosts the contracts that power the Sch0lar protocol. It utilizes the Hardhat runtime environment for testing and deployment to local testnets.

### NOTE:

If editing in VS-code, openzeppelin imports often are not picked up by the syntax reader - if ever in doubt, copy and paste into remix.ethereum.org and compile for better warnings and error handlings.

---

Try running some of the following tasks with Hardhat:

```shell
npx hardhat accounts

npx hardhat compile

npx hardhat clean

npx hardhat test

npx hardhat node

node scripts/deploy.js

npx hardhat help
```

## To start

Install dependencies

```shell
npm install
```

Start a local node (local blockchain)

```shell
npx hardhat node
```

Open a new terminal and deploy the smart contract in the localhost network

```shell
npx hardhat run --network localhost scripts/deploy.js
```

Or, test your contracts with written unit tests (doesn't require a node running or contracts deployed).

```shell
npx hardhat test
```

## Configure MetaMask

Download [MetaMask](https://metamask.io) by adding a custom network with the following fields:

### Network Name

`Hardhat`

### New RPC URL

`http://localhost:8545`

### Chain ID

`31337`

### Currency Symbol

`ETH`

# Paths to determine contributed amounts

## Problem: determine amount donated by each contributer and to which entity

### Variables:

- acpdTime, acpdAmount,

Log contribution size and time entered
timeEntered = timestamp
lastAutoCompoundTime = timestamp
nextAutoCompoundTime = timestamp
enteredBetweenAutoCompounds = timeEntered > lastAutoCompoundTime && timeEntered <= nextAutoCompoundTime
exitedBetweenAutoCompounds = timeExited > lastAutoCompoundTime && timeExited <= nextAutoCompoundTime
timeEntered = enteredBetweenAutoCompounds ? timeEntered : !exitedBetweenAutoCompounds ? nextAutoCompoundTime : lastAutoCompoundtime // timeEntered if in range, 0 if
timeExited = exitedBetweenAutoCompounds ? timeExited : lastAutoCompoundTime
// =====entry-----------acmpd => = is uncounted, - is counted
weightedEntries = size _ (nextAutoCompoundTime - timeExited) / (nextAutoCompoundTime - lastAutoCompoundTime) // fraction is between 0-1 if timeEntered is in range, 1 if no exit and was already in previously, and 0 if exited during this period between compounds
// -----exit============acmpd => = is uncounted, - is counted
weightedExits = size _ (timeExited - lastAutoCompoundTime) / (nextAutoCompoundTime - lastAutoCompoundTime) // fraction is between 0-1 if timeExited is in range, 0 if else
weightedSize = weightedEntries + weightedExits
Amount contributed from their account for given autocompoundTime = acpdAmount \* weightedSize[i] / sumAll( weightedSize )

Steps:

1. Query blockchain for all deposit / withdraw txns from last autocompound to current
2.
