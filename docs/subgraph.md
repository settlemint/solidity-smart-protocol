# SMART Protocol Subgraph

The SMART Protocol subgraph provides comprehensive indexing of all on-chain events and data for regulatory-compliant tokenization. It enables real-time querying of identity management, compliance rules, token operations, and access control.

## Features

### Identity Management

- **Identity Registry**: Complete indexing of identity registries with linked storage contracts
- **On-Chain Claims**: Structured indexing of ERC-735 claims with topic scheme decoding
- **Identity Storage**: Full integration with identity registry storage for efficient data retrieval
- **Claim Issuers**: Tracking of trusted issuers and their claim validation capabilities

### Compliance & Regulatory

- **Compliance Modules**: Real-time updates to compliance rules and module configurations
- **Transfer Validation**: Complete audit trail of compliance checks for all token transfers
- **Country Restrictions**: Indexing of jurisdiction-specific allow/block lists
- **Required Claims**: Topic-based requirements tracking for different asset types

### Token Operations

- **ERC-20 Transfers**: Full transfer history with compliance context and validation results
- **Token Lifecycle**: Mint, burn, and redemption events with regulatory annotations
- **Balance Snapshots**: Historical balance tracking for governance and reporting
- **Yield Distribution**: Automated indexing of dividend and yield payment events

### Access Control

- **Role Management**: Complete tracking of role assignments and revocations
- **Permission Changes**: Real-time updates to access control modifications
- **Token Access**: Specialized indexing for token-specific access management
- **Administrative Actions**: Audit trail of all system administrative changes

### Advanced Features

- **Topic Scheme Registry**: Structured claim data with automatic decoding support
- **Cross-Contract Relationships**: Linked data between tokens, identities, and compliance
- **Event Aggregation**: Efficient querying of related events across multiple contracts
- **Real-Time Updates**: Live indexing of blockchain events with minimal latency

## Deployment

### Setup

To index your smart contract events, use The Graph middleware.
First, edit `subgraph.config.json` to set the addresses of your smart contracts. You can find them in the deployment folder created under `ignition`.

### Authentication

```shell
bunx settlemint login
```

This logs you in to the platform. This command only needs to be run once, so you can skip it if you've already logged in.

### Deploy

```shell
bunx settlemint scs subgraph deploy
```

### Local Development

For local development and testing:

```shell
# Start local graph node
npm run graph:local:setup

# Deploy to local node
npm run graph:local:deploy

# Query local subgraph
npm run graph:local:query
```

## Example Queries

### Get Identity Information

```graphql
query GetIdentity($address: String!) {
  identity(id: $address) {
    id
    owner
    registry {
      id
      identityRegistryStorage {
        id
      }
    }
    claims {
      id
      topic
      scheme
      issuer
      signature
      data
      uri
      decodedValue {
        stringValue
        uintValue
        boolValue
        bytesValue
      }
    }
    country
    investorCountry
  }
}
```

### Get Token Compliance Status

```graphql
query GetTokenCompliance($tokenAddress: String!) {
  token(id: $tokenAddress) {
    id
    name
    symbol
    compliance {
      id
      modules {
        id
        module
        parameters {
          parameter
          value
        }
      }
    }
    requiredClaimTopics
    transfers(first: 10, orderBy: timestamp, orderDirection: desc) {
      id
      from
      to
      value
      timestamp
      compliance {
        isCompliant
        moduleResults
      }
    }
  }
}
```

### Get Access Control Events

```graphql
query GetAccessControlEvents($tokenAddress: String!) {
  accessControlEvents(
    where: { token: $tokenAddress }
    first: 50
    orderBy: timestamp
    orderDirection: desc
  ) {
    id
    type
    account
    role
    sender
    timestamp
    transaction
  }
}
```

## Schema Overview

The subgraph schema includes the following main entities:

- **Identity**: On-chain identities with claims and registry associations
- **IdentityRegistry**: Registry contracts managing identity verification
- **IdentityRegistryStorage**: Storage contracts for identity data
- **Claim**: ERC-735 claims with structured value decoding
- **Token**: ERC-20 tokens with compliance and regulatory features
- **Compliance**: Compliance contracts with modular rule validation
- **Transfer**: Token transfers with compliance validation context
- **AccessControlEvent**: Role-based permission change events
- **TopicSchemeRegistry**: Registry for claim topic schemas and decoding

## Help

To get info about the available commands, run:

```shell
bunx settlemint scs subgraph --help
```

## Advanced Usage

### Monitoring Compliance

The subgraph enables real-time monitoring of compliance status across all tokens in the system. This is particularly useful for:

- Regulatory reporting and audit trails
- Real-time compliance dashboards
- Automated alert systems for policy violations
- Analytics on identity verification patterns

### Integration with DApps

The indexed data can be used to build sophisticated DApps that require:

- Real-time compliance checking before transactions
- Historical analysis of token holder patterns
- Identity verification status displays
- Governance voting weight calculations based on historical balances

### Performance Optimization

The subgraph is optimized for:

- Fast queries on identity verification status
- Efficient compliance rule lookups
- Scalable indexing of high-volume transfer events
- Cross-contract relationship resolution
