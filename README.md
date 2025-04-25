# SMART Protocol

✨ [https://settlemint.com](https://settlemint.com) ✨

Build your own blockchain usecase with ease.

[![CI status](https://github.com/settlemint/solidity-empty/actions/workflows/solidity.yml/badge.svg?event=push&branch=main)](https://github.com/settlemint/solidity-empty/actions?query=branch%3Amain) [![License](https://img.shields.io/npm/l/@settlemint/solidity-empty)](https://fsl.software) [![npm](https://img.shields.io/npm/dw/@settlemint/solidity-empty)](https://www.npmjs.com/package/@settlemint/solidity-empty) [![stars](https://img.shields.io/github/stars/settlemint/solidity-empty)](https://github.com/settlemint/solidity-empty)

[Documentation](https://console.settlemint.com/documentation/) • [Discord](https://discord.com/invite/Mt5yqFrey9) • [NPM](https://www.npmjs.com/package/@settlemint/solidity-empty) • [Issues](https://github.com/settlemint/solidity-empty/issues)

## Changes from ERC-3643

- Token stores required claim topics and initial modules in the contract, allowing re-use of identity registry and compliance contract
- Token is more modular following the OpenZeppelin modular pattern
- Only modular compliance rules, but you can also choose to just create one compliance contract without the modules at all
- Token doesn't need to be bound to compliance contract, added _token parameter to all functions
- Removed the need to a separate claims topics registry, since we don't use it anymore
- Token will be passed in isVerified function to check if the identity has all the necessary claim topics
- Simplified the identity factory using proxy 1967 pattern.
- SMARTRedeemable extension for self-burning tokens. ERC3643 isn't compliant with ERC20Burnable, it only has a burn(user, amount) function which is guarded by the owner. While ERC20Burnable has a burn(amount) and burnFrom(user, amount) function. We created a separate extension to also allow burning your own tokens in some situations.

## TODO

- Should modules be upgradeable?
- Permit? or can we use ERC20 permit?
- Allowance? or can we use ERC20 allowance?
- Make compliance an extension?
- Merge burn and redeem?

## Get started

Launch this smart contract set in SettleMint under the `Smart Contract Sets` section. This will automatically link it to your own blockchain node and make use of the private keys living in the platform.

If you want to use it separately, bootstrap a new project using

```shell
forge init my-project --template settlemint/solidity-empty
```

Or if you want to use this set as a dependency of your own,

```shell
bun install @settlemint/solidity-empty
```

## DX: Foundry & Hardhat hybrid

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

**Hardhat is a Flexible, Extensible, Fast Ethereum development environment for professionals in typescript**

Hardhat consists of:

- **Hardhat Runner**: Hardhat Runner is the main component you interact with when using Hardhat. It's a flexible and extensible task runner that helps you manage and automate the recurring tasks inherent to developing smart contracts and dApps.
- **Hardhat Ignition**: Declarative deployment system that enables you to deploy your smart contracts without navigating the mechanics of the deployment process.
- **Hardhat Network**: Declarative deployment system that enables you to deploy your smart contracts without navigating the mechanics of the deployment process.

## Documentation

- Additional documentation can be found in the [docs folder](./docs).
- [SettleMint Documentation](https://console.settlemint.com/documentation/docs/using-platform/dev-tools/code-studio/smart-contract-sets/deploying-a-contract/)
- [Foundry Documentation](https://book.getfoundry.sh/)
- [Hardhat Documentation](https://hardhat.org/hardhat-runner/docs/getting-started)


