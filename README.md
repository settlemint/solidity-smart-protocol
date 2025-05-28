# SMART Protocol

✨ [https://settlemint.com](https://settlemint.com) ✨

**A comprehensive Solidity smart contract framework for regulatory-compliant tokenization of real-world assets (RWAs)**

[![CI status](https://github.com/settlemint/solidity-smart-protocol/actions/workflows/solidity.yml/badge.svg?event=push&branch=main)](https://github.com/settlemint/solidity-smart-protocol/actions?query=branch%3Amain) [![License](https://img.shields.io/npm/l/@settlemint/solidity-smart-protocol)](https://fsl.software) [![npm](https://img.shields.io/npm/dw/@settlemint/solidity-smart-protocol)](https://www.npmjs.com/package/@settlemint/solidity-smart-protocol) [![stars](https://img.shields.io/github/stars/settlemint/solidity-smart-protocol)](https://github.com/settlemint/solidity-smart-protocol)

[Documentation](https://console.settlemint.com/documentation/) • [Discord](https://discord.com/invite/Mt5yqFrey9) • [NPM](https://www.npmjs.com/package/@settlemint/solidity-smart-protocol) • [Issues](https://github.com/settlemint/solidity-smart-protocol/issues)

## 📋 What is SMART Protocol?

SMART Protocol is an advanced, modular smart contract framework designed for creating regulatory-compliant security tokens and tokenizing real-world assets. Built on multiple ERC standards, it provides a complete infrastructure for:

- **Security Token Issuance**: ERC-3643 compliant tokens for regulated financial instruments
- **Asset Tokenization**: Bonds, equity shares, deposits, funds, and stablecoins
- **Identity Management**: On-chain KYC/AML compliance with ERC-734/735 identities
- **Regulatory Compliance**: Modular compliance rules for different jurisdictions
- **DeFi Integration**: Full ERC-20 compatibility for seamless ecosystem integration

## 🏗️ Architecture Overview

SMART Protocol consists of three main layers:

### 1. **Token Layer**

Core ERC-20 compliant tokens with specialized implementations:

- **SMARTBond**: For debt instruments and bond tokenization
- **SMARTEquity**: For equity shares and ownership tokens
- **SMARTDeposit**: For deposit certificates and savings products
- **SMARTFund**: For fund shares and investment vehicles
- **SMARTStableCoin**: For stable value digital currencies

### 2. **Extension Layer**

Modular components that add specific functionality:

- **SMARTBurnable**: Token burning capabilities
- **SMARTCustodian**: Address freezing and forced transfers
- **SMARTCollateral**: Collateral proof requirements
- **SMARTPausable**: Emergency pause functionality
- **SMARTRedeemable**: Token redemption features
- **SMARTYield**: Yield/dividend distribution
- **SMARTHistoricalBalances**: Balance snapshot tracking

### 3. **System Layer**

Infrastructure contracts for identity and compliance:

- **Identity Management**: ERC-734/735 compliant on-chain identities
- **Compliance Engine**: ERC-3643 regulatory compliance validation
- **Access Control**: Role-based permission management
- **Trust Registry**: Trusted claim issuers for KYC/AML

## 🔌 ERC Standards Implemented

SMART Protocol implements multiple Ethereum standards to provide comprehensive functionality:

### **ERC-20: Fungible Token Standard**

- **Full Compatibility**: Complete ERC-20 and ERC-20 Metadata implementation
- **DeFi Ready**: Works seamlessly with DEXs, lending protocols, and wallets
- **Extensions**: Transfer hooks, pausable transfers, burnable tokens
- **Upgradeability**: UUPS proxy pattern support for contract upgrades

### **ERC-3643: T-REX Security Token Standard**

- **Regulatory Compliance**: Built-in KYC/AML and jurisdiction-specific rules
- **Transfer Restrictions**: Conditional transfers based on investor eligibility
- **Identity Verification**: Integration with trusted identity providers
- **Compliance Modules**: Pluggable rules for different regulatory requirements
- **Components**:
  - Identity Registry for investor management
  - Compliance validation engine
  - Trusted issuers registry for claim verification
  - Claim topics for required documentation types

### **ERC-734: Key Holder Standard**

- **On-chain Identity**: Self-sovereign identity management
- **Multi-purpose Keys**: Management, action, claim signing, and encryption keys
- **Execution Framework**: Multi-signature execution with key-based approval
- **Key Management**: Add, remove, and replace keys with proper authorization

### **ERC-735: Claim Holder Standard**

- **Verifiable Claims**: On-chain attestations about identity attributes
- **Trusted Issuers**: Claims validated by authorized third parties
- **Topic-based Organization**: Claims categorized by topics (KYC, nationality, etc.)
- **Revocation Support**: Ability to revoke outdated or invalid claims

### **ERC-2771: Meta-Transaction Standard**

- **Gasless Transactions**: Users can transact without holding ETH
- **Improved UX**: Third-party relayers can sponsor transaction costs
- **Trusted Forwarders**: Secure delegation of transaction execution
- **Native Integration**: Built into all SMART Protocol contracts

### **ERC-5313: Light Contract Ownership**

- **Access Control**: Role-based permission system
- **Batch Operations**: Efficient multi-role management
- **OpenZeppelin Integration**: Compatible with existing access control patterns

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
| **Immutability**                         | Name and symbol are mutable                     | Following ERC20, which makes it immutable                            | Following the ERC20 standard                                   |

## ✅ Conclusion

SMART rethinks the ERC-3643 architecture by moving modularity, configuration, and verification closer to the token layer. This creates a more flexible, reusable, and standards-compliant framework for compliant token issuance in dynamic regulatory environments. By decoupling identity and compliance logic from any single token, SMART improves scalability and opens doors for broader cross-application identity use.

## 🚀 How to Use SMART Protocol

### **Quick Start: Asset Tokenization**

1. **Deploy System Infrastructure**

   ```solidity
   // Deploy the core system with identity and compliance infrastructure
   SMARTSystemFactory systemFactory = new SMARTSystemFactory();
   SMARTSystem system = systemFactory.deploySystem(
       "MyProject",
       systemAdmin,
       complianceAdmin
   );
   ```

2. **Create Asset-Specific Tokens**

   ```solidity
   // Deploy a bond token
   SMARTBondFactory bondFactory = system.getBondFactory();
   SMARTBondProxy bond = bondFactory.deployToken(
       "Green Bond 2024",
       "GB24",
       18,
       systemAdmin,
       [Topics.KYC, Topics.ACCREDITED_INVESTOR] // Required claims
   );
   ```

3. **Set Up Identity and Compliance**

   ```solidity
   // Register investors with required claims
   SMARTIdentity investorIdentity = system.createIdentity(investorAddress);

   // Issue KYC claim through trusted issuer
   system.getTrustedIssuersRegistry().addTrustedIssuer(
       kycProviderIdentity,
       [Topics.KYC]
   );

   // Investor gets verified through KYC provider
   kycProvider.issueClaim(investorIdentity, Topics.KYC, kycData);
   ```

4. **Configure Token Extensions**

   ```solidity
   // Add yield distribution capability
   bond.addExtension(address(new SMARTYield()));

   // Set up custodian controls
   bond.addExtension(address(new SMARTCustodian()));

   // Enable token redemption
   bond.addExtension(address(new SMARTRedeemable()));
   ```

### **Advanced Usage Patterns**

#### **Multi-Jurisdiction Compliance**

```solidity
// Set up country-specific rules
CountryAllowListModule allowList = new CountryAllowListModule();
allowList.addAllowedCountry("US");
allowList.addAllowedCountry("EU");

CountryBlockListModule blockList = new CountryBlockListModule();
blockList.addBlockedCountry("OFAC_SANCTIONED");

// Apply to compliance
system.getCompliance().addModule(address(allowList));
system.getCompliance().addModule(address(blockList));
```

#### **Custom Yield Schedules**

```solidity
// Fixed yield schedule for bonds
SMARTFixedYieldSchedule schedule = new SMARTFixedYieldSchedule();
schedule.setYieldRate(5 * 10**16); // 5% annual yield
schedule.setPaymentFrequency(90 days); // Quarterly

bond.setYieldSchedule(address(schedule));
```

#### **Collateral Management**

```solidity
// Require collateral proof for high-value transfers
SMARTCollateral collateralExt = SMARTCollateral(bond.getExtension("SMARTCollateral"));
collateralExt.setCollateralRequirement(
    1000 * 10**18, // Amounts over 1000 tokens
    collateralProofContract
);
```

### **Integration Examples**

#### **DeFi Integration**

```solidity
// SMART tokens work with any ERC-20 compatible protocol
// Example: Uniswap V3 liquidity provision
IUniswapV3Factory factory = IUniswapV3Factory(UNISWAP_V3_FACTORY);
IUniswapV3Pool pool = factory.createPool(
    address(smartToken),
    address(usdc),
    3000 // 0.3% fee
);

// Note: Compliance rules still apply to all transfers
```

#### **Cross-Chain Asset Bridging**

```solidity
// Bridge assets while maintaining compliance
function bridgeAsset(
    address token,
    uint256 amount,
    uint256 destinationChain,
    address recipient
) external {
    // Compliance check before bridging
    require(ISMART(token).canTransfer(msg.sender, recipient, amount), "Transfer not compliant");

    // Bridge logic...
    bridgeContract.lockAndMint(token, amount, destinationChain, recipient);
}
```

### **Common Use Cases**

| **Use Case**               | **Asset Type**  | **Key Extensions**             | **Compliance Requirements**           |
| -------------------------- | --------------- | ------------------------------ | ------------------------------------- |
| **Corporate Bonds**        | SMARTBond       | Yield, Redeemable, Pausable    | Accredited investor, KYC              |
| **Real Estate Shares**     | SMARTEquity     | Custodian, Historical Balances | KYC, Jurisdiction restrictions        |
| **Tokenized Deposits**     | SMARTDeposit    | Yield, Capped                  | Bank verification, deposit insurance  |
| **Investment Funds**       | SMARTFund       | Yield, Custodian, Burnable     | Fund prospectus, investor suitability |
| **Regulatory Stablecoins** | SMARTStableCoin | Pausable, Custodian            | Money transmitter license             |

## 🧪 Development & Testing

### **Running Tests**

```bash
# Run Foundry tests
forge test

# Run specific test files
forge test --match-path test/assets/SMARTBond.t.sol

# Run with gas reporting
forge test --gas-report

# Run Hardhat tests for integration scenarios
npm run test
```

### **Deployment**

```bash
# Deploy using Hardhat Ignition
npx hardhat ignition deploy ignition/modules/main.ts --network <network>

# Deploy using Forge
forge script scripts/Deploy.s.sol --rpc-url <rpc-url> --broadcast
```

### **Local Development**

```bash
# Start local blockchain
anvil

# Deploy to local network
forge script scripts/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### **Subgraph Integration**

SMART Protocol includes a comprehensive subgraph for indexing on-chain events and data:

- **Identity Management**: Complete indexing of identity registries, storage, and on-chain claims
- **Compliance Tracking**: Real-time compliance rule updates and transfer validations
- **Token Operations**: Full ERC-20 transfer history with compliance context
- **Access Control**: Role-based permission changes and token access management
- **Topic Scheme Registry**: Structured claim data with decoding support

```bash
# Deploy subgraph to The Graph
bunx settlemint scs subgraph deploy

# Query subgraph locally
npm run graph:local
```

### **Gas Optimization**

SMART Protocol includes several gas optimization features:

- **Batch Operations**: Multi-user operations in single transactions
- **Efficient Storage**: Packed structs and optimized storage layout
- **Meta-Transactions**: Reduce user gas costs via ERC-2771
- **Proxy Patterns**: UUPS upgradeable contracts for reduced deployment costs

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
