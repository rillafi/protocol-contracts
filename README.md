# Sch0lar Contracts

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, a sample script that deploys that contract, and an example of a task implementation, which simply lists the available accounts.

Try running some of the following tasks with Hardhat:

```shell

npx hardhat accounts

npx hardhat compile

npx hardhat clean

npx hardhat test

npx hardhat node

node scripts/sample-script.js

npx hardhat help

```

# To start

Start a local node

```shell

npx hardhat node

```

Open a new terminal and deploy the smart contract in the localhost network

```shell

npx hardhat run --network localhost scripts/deploy.js

```

# Configure MetaMask

Download [MetaMask](https://metamask.io) by adding a custom network with the following fields:

### Network Name

`Hardhat`

### New RPC URL

`http://localhost:8545`

### Chain ID

`31337`

### Currency Symbol

`ETH`
