# AGENTS.md

This file provides guidance to Codex when working with code in this repository.

## Development Commands

### Building and Testing

```bash
# Build with Foundry (preferred for development)
npm run compile:forge

# Build with Hardhat (for deployments)
npm run compile:hardhat

# Run all tests (Foundry)
npm run test

# Run specific test file
forge test --match-path test/assets/SMARTBond.t.sol

# Run tests with gas reporting
forge test --gas-report

# Run with increased verbosity for debugging
forge test -vvv

# Run coverage analysis
npm run coverage
```

### Code Quality

```bash
# Lint Solidity code
npm run lint

# Format code
npm run format

# Install dependencies (includes soldeer dependencies)
npm run dependencies
```

### Deployment

```bash
# Deploy to local network (with onboarding setup)
npm run deploy:local:onboarding

# Deploy for testing
npm run deploy:local:test

# Deploy to remote (requires settlemint login)
npm run deploy:remote
```

## Architecture Overview

SMART Protocol is a three-layer architecture for regulatory-compliant tokenization:

### 1. Token Layer (`contracts/`)

Core asset tokens that are fully ERC-20 compatible:

- **SMARTBond**: Debt instruments with yield distribution and redemption
- **SMARTEquity**: Equity shares with voting and dividend capabilities
- **SMARTDeposit**: Deposit certificates with collateral requirements
- **SMARTFund**: Investment fund shares with management fees
- **SMARTStableCoin**: Regulatory-compliant stable value tokens

### 2. Extension Layer (`contracts/extensions/`)

Modular functionality that can be added to any token:

- **Core (`extensions/core/`)**: Base SMART logic with compliance and identity verification
- **Burnable**: Token burning capabilities for both owner and self-burn scenarios
- **Custodian**: Address freezing, partial freezing, and forced transfers
- **Collateral**: Proof-of-collateral requirements for large transfers
- **Pausable**: Emergency pause functionality
- **Redeemable**: User-initiated token redemption (distinct from burning)
- **Yield**: Dividend/yield distribution with configurable schedules
- **Historical Balances**: Snapshot functionality for governance voting
- **Access Managed**: Integration with external access control systems

### 3. System Layer (`contracts/system/`)

Infrastructure for identity and compliance (ERC-3643 compliant):

- **Identity Management**: ERC-734/735 on-chain identities for wallets and tokens
- **Compliance Engine**: Modular rule validation with jurisdiction-specific modules
- **Access Control**: Role-based permissions using ERC-5313
- **Trusted Issuers Registry**: KYC/AML claim issuer management

## Key Design Patterns

### Proxy Pattern

- All system contracts use UUPS (ERC-1822) upgradeable proxies
- Logic contracts are in `*Implementation.sol` files
- Proxy contracts are in `*Proxy.sol` files
- Factory contracts deploy new proxy instances

### Extension System

- Tokens inherit from `SMART` or `SMARTUpgradeable` base
- Extensions are mixed in via multiple inheritance
- Extensions follow OpenZeppelin's pattern with `_ExtensionLogic.sol` internal libraries

### Identity & Compliance Integration

- Transfers automatically check `isVerified()` via identity registry
- Compliance modules can block transfers based on custom rules
- Claim topics are configurable per token (e.g., KYC, accredited investor status)

### Meta-Transaction Support (ERC-2771)

- All contracts support gasless transactions via trusted forwarders
- Use `_msgSender()` instead of `msg.sender` throughout codebase

## Important Implementation Details

### Transfer Hooks

The `_beforeTokenTransfer` and `_afterTokenTransfer` hooks are used extensively for:

- Compliance validation
- Extension-specific logic (freezing, collateral checks, etc.)
- Historical balance tracking
- Yield distribution triggers

### Solidity Version & Compiler Settings

- Uses Solidity 0.8.28 with Cancun EVM features
- Via-IR compilation enabled for gas optimization
- Optimizer runs set to 200 for production deployments

### Testing Architecture

Tests are organized by layer:

- `test/assets/`: Asset-specific token tests
- `test/system/`: Infrastructure contract tests
- `test/tests/`: Cross-cutting integration tests
- `test/utils/`: Test utilities and mocks

### Constants and Configuration

- Claim topics defined in `test/Constants.sol`
- System roles in `contracts/system/SMARTSystemRoles.sol`
- Asset-specific topics in `contracts/assets/SMARTTopics.sol`

## Development Notes

### When Adding New Extensions

1. Create interface in `extensions/[name]/I[Name].sol`
2. Implement logic in `extensions/[name]/internal/_[Name]Logic.sol`
3. Create standard and upgradeable versions
4. Add comprehensive tests following existing patterns

### When Modifying Core Logic

- Always consider impact on all asset types
- Ensure ERC-20 compatibility is maintained
- Update both standard and upgradeable versions
- Test with all extension combinations

### Common Gotchas

- Use `_msgSender()` for ERC-2771 compatibility, not `msg.sender`
- Handle return values from external calls (Slither will flag unused returns)
- Extension order matters in multiple inheritance - follow existing patterns
- Always initialize storage variables in upgradeable contracts

### Deployment Order

1. Deploy system infrastructure (SMARTSystemFactory)
2. Deploy asset factories via system
3. Deploy individual tokens via factories
4. Configure compliance rules and trusted issuers
5. Set up identity verification for users

## Commit message instructions

- We use conventional commits WITHOUT a scope, so please follow the following format:

```
<type>: <description>

[optional body]

[optional footer]
```

- The type can be one of the following:

  - fix -> if we are fixing a bug
  - feat -> if we are adding a new feature
  - chore -> if we are doing a small change that doesn't fit in the other categories

- The description should be a short description of the change.
- The body should be used to provide more context about the change.
- The footer is optional and can be used to provide more information about the change.
- Never use breaking changes!
