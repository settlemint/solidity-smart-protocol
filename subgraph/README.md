# SMART Protocol Subgraph

This subgraph indexes events and entities from the SMART Protocol smart contracts, providing a GraphQL API for querying tokenization data, identity management, compliance, and access control information.

## Entity Relationships

The following diagram shows the relationships between all entities in the SMART Protocol subgraph:

```mermaid
erDiagram
    Account ||--o{ Event : emits
    Account ||--o{ Event : sends
    Account ||--o{ Event : involved_in
    Account ||--o| Identity : has

    Event ||--o{ EventValue : contains

    AccessControl ||--o{ Account : admin
    AccessControl ||--o{ Account : registrar
    AccessControl ||--o{ Account : registrar_admin
    AccessControl ||--o{ Account : registrar_governor
    AccessControl ||--o{ Account : claim_manager
    AccessControl ||--o{ Account : identity_issuer
    AccessControl ||--o{ Account : token_identity_issuer
    AccessControl ||--o{ Account : token_identity_issuer_admin
    AccessControl ||--o{ Account : token_deployer
    AccessControl ||--o{ Account : storage_modifier
    AccessControl ||--o{ Account : manage_registries
    AccessControl ||--o{ Account : token_governance
    AccessControl ||--o{ Account : supply_management
    AccessControl ||--o{ Account : custodian
    AccessControl ||--o{ Account : emergency

    System ||--|| AccessControl : has
    System ||--o| Account : has
    System ||--o| Compliance : has
    System ||--o| IdentityRegistryStorage : has
    System ||--o| IdentityFactory : has
    System ||--o| IdentityRegistry : has
    System ||--o| TrustedIssuersRegistry : has
    System ||--o| TopicSchemeRegistry : has
    System ||--o{ TokenFactory : manages

    Compliance ||--|| Account : managed_by

    IdentityRegistryStorage ||--|| AccessControl : has
    IdentityRegistryStorage ||--|| Account : managed_by

    IdentityFactory ||--|| AccessControl : has
    IdentityFactory ||--|| Account : managed_by

    IdentityRegistry ||--|| AccessControl : has
    IdentityRegistry ||--|| Account : managed_by
    IdentityRegistry ||--o{ Identity : registers
    IdentityRegistry ||--o| TrustedIssuersRegistry : uses
    IdentityRegistry ||--o| TopicSchemeRegistry : uses

    TrustedIssuersRegistry ||--|| AccessControl : has
    TrustedIssuersRegistry ||--|| Account : managed_by

    TopicSchemeRegistry ||--|| AccessControl : has
    TopicSchemeRegistry ||--|| Account : managed_by
    TopicSchemeRegistry ||--o{ TopicScheme : contains

    TopicScheme ||--|| TopicSchemeRegistry : belongs_to

    TokenFactory ||--|| AccessControl : has
    TokenFactory ||--o| System : belongs_to
    TokenFactory ||--|| Account : managed_by
    TokenFactory ||--o{ Token : creates

    Token ||--|| Account : managed_by
    Token ||--o| AccessControl : has
    Token ||--o| Identity : has
    Token ||--o| TokenFactory : created_by
    Token ||--o| TokenPausable : has_pausable_state

    TokenPausable {
        Bytes id
        Boolean paused
    }

    Identity ||--o| IdentityRegistry : registered_in
    Identity ||--o{ IdentityClaim : has

    IdentityClaim ||--|| Identity : belongs_to
    IdentityClaim ||--o| Account : issued_by
    IdentityClaim ||--o{ IdentityClaimValue : contains

    IdentityClaimValue ||--|| IdentityClaim : belongs_to

    Account {
        Bytes id
        Boolean isContract
    }

    Event {
        Bytes id
        String eventName
        BigInt txIndex
        BigInt blockNumber
        BigInt blockTimestamp
        Bytes transactionHash
    }

    EventValue {
        Bytes id
        String name
        String value
    }

    AccessControl {
        Bytes id
    }

    System {
        Bytes id
    }

    Compliance {
        Bytes id
    }

    IdentityRegistryStorage {
        Bytes id
    }

    IdentityFactory {
        Bytes id
    }

    IdentityRegistry {
        Bytes id
    }

    TrustedIssuersRegistry {
        Bytes id
    }

    TopicSchemeRegistry {
        Bytes id
    }

    TopicScheme {
        Bytes id
        String signature
        BigInt topicId
        Boolean enabled
    }

    TokenFactory {
        Bytes id
        String type
    }

    Token {
        Bytes id
        String type
        String name
        String symbol
        Int decimals
        BigDecimal totalSupply
        BigInt totalSupplyExact
    }

    Identity {
        Bytes id
    }

    IdentityClaim {
        Bytes id
        String uri
        Boolean revoked
    }

    IdentityClaimValue {
        Bytes id
        String key
        String value
    }
```

## Key Entity Types

### Core System Entities

- **System**: Central system entity that manages all protocol components
- **AccessControl**: Role-based access control for different system functions
- **Account**: Represents Ethereum addresses (both contracts and EOAs)

### Identity & Compliance

- **Identity**: On-chain identities for wallets and tokens (ERC-734/735)
- **IdentityRegistry**: Manages registered identities and their validation
- **IdentityClaim**: Claims associated with identities (KYC, accreditation, etc.)
- **IdentityClaimValue**: Structured data within claims
- **TrustedIssuersRegistry**: Registry of authorized claim issuers
- **Compliance**: Compliance validation engine

### Token Infrastructure

- **TokenFactory**: Factory contracts for creating new tokens
- **Token**: Asset tokens (bonds, equity, deposits, funds, stablecoins)
- **TokenPausable**: Pausable state for tokens

### Topic & Scheme Management

- **TopicSchemeRegistry**: Registry for claim topic schemas
- **TopicScheme**: Individual topic schema definitions

### Event Tracking

- **Event**: All blockchain events with metadata
- **EventValue**: Structured event parameter data

## Usage

The subgraph provides a GraphQL endpoint for querying all protocol data. Common query patterns include:

- Fetching all tokens created by a specific factory
- Finding identities registered in a particular registry
- Tracking compliance events and access control changes
- Analyzing token transfers and supply changes
- Monitoring claim issuance and revocation

## Indexing Flow

The following flowchart shows how events flow through the subgraph's event handlers and create/update entities:

```mermaid
flowchart TD
    A[SystemFactory Contract] -->|SMARTSystemCreated event| B[handleSMARTSystemCreated]
    B --> C[fetchSystem]
    C --> D[System Entity Created]
    D --> E[AccessControl Template Started]

    F[System Contract] -->|Bootstrapped event| G[handleBootstrapped]
    G --> H[fetchCompliance]
    G --> I[fetchIdentityRegistry]
    G --> J[fetchIdentityRegistryStorage]
    G --> K[fetchTrustedIssuersRegistry]
    G --> L[fetchIdentityFactory]
    G --> M[fetchTopicSchemeRegistry]

    H --> N[Compliance Entity]
    I --> O[IdentityRegistry Entity]
    J --> P[IdentityRegistryStorage Entity]
    K --> Q[TrustedIssuersRegistry Entity]
    L --> R[IdentityFactory Entity]
    M --> S[TopicSchemeRegistry Entity]

    O --> T[IdentityRegistry Template Started]
    S --> U[TopicSchemeRegistry Template Started]

    F -->|TokenFactoryCreated event| V[handleTokenFactoryCreated]
    V --> W[fetchTokenFactory]
    W --> X[TokenFactory Entity]
    X --> Y[Token Template Started]

    Z[IdentityRegistry Contract] -->|IdentityRegistered event| AA[handleIdentityRegistered]
    AA --> BB[fetchIdentity]
    BB --> CC[Identity Entity]
    CC --> DD[Identity Template Started]

    Z -->|IdentityRemoved event| EE[handleIdentityRemoved]
    EE --> FF[Update Identity Entity]

    Z -->|TrustedIssuersRegistrySet event| GG[handleTrustedIssuersRegistrySet]
    GG --> HH[Update IdentityRegistry Entity]

    II[Identity Contract] -->|ClaimAdded event| JJ[handleClaimAdded]
    JJ --> KK[fetchIdentityClaim]
    KK --> LL[IdentityClaim Entity]
    LL --> MM[decodeClaimValues]
    MM --> NN[IdentityClaimValue Entities]

    II -->|ClaimRemoved event| OO[handleClaimRemoved]
    OO --> PP[Update IdentityClaim Entity as revoked]

    QQ[Token Contract] -->|Transfer event| RR[handleTransferCompleted]
    RR --> SS[Update Token Supply]

    QQ -->|Mint event| TT[handleMintCompleted]
    TT --> UU[Update Token Supply]

    VV[TopicSchemeRegistry Contract] -->|TopicSchemeRegistered event| WW[handleTopicSchemeRegistered]
    WW --> XX[fetchTopicScheme]
    XX --> YY[TopicScheme Entity]

    ZZ[AccessControl Contract] -->|RoleGranted event| AAA[handleRoleGranted]
    AAA --> BBB[Update AccessControl Entity]

    ZZ -->|RoleRevoked event| CCC[handleRoleRevoked]
    CCC --> DDD[Update AccessControl Entity]

    subgraph "Cross-cutting Concerns"
        EEE[All Event Handlers] --> FFF[fetchEvent]
        FFF --> GGG[Event Entity]
        GGG --> HHH[EventValue Entities]

        III[All Fetch Functions] --> JJJ[fetchAccount]
        JJJ --> KKK[Account Entity]
    end

    style A fill:#e1f5fe
    style F fill:#e8f5e8
    style Z fill:#fff3e0
    style II fill:#f3e5f5
    style QQ fill:#fce4ec
    style VV fill:#e0f2f1
    style ZZ fill:#fff8e1
```

## Development

The subgraph is built using The Graph Protocol and indexes events from SMART Protocol smart contracts deployed on the SettleMint network.

### Indexing Architecture

1. **Data Sources**: The main entry point is the SystemFactory contract which deploys new System instances
2. **Templates**: Dynamic contract indexing is enabled through templates for System, IdentityRegistry, Identity, Token, and other components
3. **Event Processing**: Each event handler follows a pattern of fetching/creating entities and updating relationships
4. **Cross-cutting Concerns**:
   - All events are tracked in the Event entity for audit trails
   - Account entities are created for all Ethereum addresses
   - AccessControl changes are tracked across all system components
