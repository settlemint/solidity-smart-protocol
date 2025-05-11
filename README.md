# SMART Protocol

✨ [https://settlemint.com](https://settlemint.com) ✨

Build your own blockchain usecase with ease.

[![CI status](https://github.com/settlemint/solidity-smart-protocol/actions/workflows/solidity.yml/badge.svg?event=push&branch=main)](https://github.com/settlemint/solidity-smart-protocol/actions?query=branch%3Amain) [![License](https://img.shields.io/npm/l/@settlemint/solidity-smart-protocol)](https://fsl.software) [![npm](https://img.shields.io/npm/dw/@settlemint/solidity-smart-protocol)](https://www.npmjs.com/package/@settlemint/solidity-smart-protocol) [![stars](https://img.shields.io/github/stars/settlemint/solidity-smart-protocol)](https://github.com/settlemint/solidity-smart-protocol)

[Documentation](https://console.settlemint.com/documentation/) • [Discord](https://discord.com/invite/Mt5yqFrey9) • [NPM](https://www.npmjs.com/package/@settlemint/solidity-smart-protocol) • [Issues](https://github.com/settlemint/solidity-smart-protocol/issues)

## 🧩 Key Highlights of SMART

- **ERC20 Compliance**: Fully implements `ERC20` and `ERC20Upgradeable`, ensuring compatibility with Ethereum tooling and DeFi ecosystems.
- **Externally Modular Architecture**: SMART uses composable extensions (e.g., `SMARTBurnable`, `SMARTCollateral`) in a plug-and-play model.
- **Token-Configurable Compliance**: SMART tokens can be configured to use specific modular rules and parameters without needing custom compliance contracts.
- **Token-Agnostic Identity Verification**: Identity registry remains reusable across tokens and use cases—tokens dynamically pass required claim topics into the verification logic.
- **Authorization Agnostic**: SMART is compatible with any authorization logic via hooks (e.g., OpenZeppelin `AccessControl`).
- **Modern Upgrade Strategy**: All components use `UUPSUpgradeable`, eliminating centralized version control requirements.
- **ERC-2771 Meta-Transaction Support**: Compatible with trusted forwarders for gasless transactions and improved UX.

## ⚖️ Overview Comparison

| **Aspect**                               | **ERC-3643**                                    | **SMART Protocol**                                                   | **Notes**                                                      |
| ---------------------------------------- | ----------------------------------------------- | -------------------------------------------------------------------- | -------------------------------------------------------------- |
| **ERC20 Compatibility**                  | Partial / constrained                           | Fully ERC20 and ERC20Upgradeable compliant                           | Ensures full compatibility with DeFi and wallets               |
| **Identity / Compliance Contract Reuse** | Typically one-off per token                     | Contracts are reusable across multiple tokens                        | Promotes efficient architecture, simplifies setup of a token   |
| **Modularity**                           | Partially modular                               | Modular by default (OpenZeppelin extension pattern)                  | SMARTBurnable, SMARTPausable, SMARTCustodian, etc.             |
| **Claim Topics Storage**                 | External Claim Topics Registry                  | Stored directly in the token                                         | Simplifies deployment and encapsulates identity verification   |
| **Compliance Model**                     | Single compliance contract, that can be modular | Modular compliance rules by default; monolithic also possible        | Flexible setup depending on project needs                      |
| **Compliance Configuration**             | No token-specific configuration                 | Rule-specific parameters can be defined per token                    | Enables rule reuse with different behaviors                    |
| **Identity Verification**                | Relies on Claim Topics Registry                 | Token passes required claim topics to `isVerified(identity, topics)` | Token-agnostic, reusable identity logic                        |
| **Burning Logic**                        | Owner-guarded `burn(user, amount)` only         | `SMARTBurnable` (owner burn) + `SMARTRedeemable` (self-burn)         | Enables user redemption scenarios, which can be used for Bonds |
| **Upgradeability**                       | Centralized via Implementation Authority        | UUPSUpgradeable per contract                                         | More decentralized and manageable upgrade control              |
| **Authorization**                        | Agent-based role system                         | Hook-based and access-control agnostic                               | Compatible with OpenZeppelin AccessControl or custom systems   |
| **Meta-Transaction Support**             | Not specified in core standard                  | ERC-2771 compatible (trusted forwarders)                             | Enables gasless transactions via relayers                      |

## ✅ Conclusion

SMART rethinks the ERC-3643 architecture by moving modularity, configuration, and verification closer to the token layer. This creates a more flexible, reusable, and standards-compliant framework for compliant token issuance in dynamic regulatory environments. By decoupling identity and compliance logic from any single token, SMART improves scalability and opens doors for broader cross-application identity use.

## Get started

Launch this smart contract set in SettleMint under the `Smart Contract Sets` section. This will automatically link it to your own blockchain node and make use of the private keys living in the platform.

If you want to use it separately, bootstrap a new project using

```shell
forge init my-project --template settlemint/solidity-smart-protocol
```

Or if you want to use this set as a dependency of your own,

```shell
bun install @settlemint/solidity-smart-protocol
```

or via soldeer

```shell
forge soldeer install smart-protocol~8.0.x
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
