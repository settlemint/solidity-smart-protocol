# SMART Collateral Extension

This extension enforces a global collateral requirement before minting new SMART tokens by verifying a specific claim on the **token contract's own identity contract**.

## Overview

The collateral extension ensures that new tokens can only be minted if the token contract's associated OnchainID identity contract holds a valid, non-expired collateral claim issued by a trusted source. This single claim dictates the maximum total supply the token contract is allowed to reach.

Key components include:

- **`_SMARTCollateralLogic.sol`**: An internal abstract contract containing the core logic for finding and validating the global collateral claim and the hook logic (`_collateral_beforeMintLogic`) that enforces the check before minting. It defines necessary custom errors (`InsufficientCollateral`, `InvalidCollateralTopic`). *Note: Depending on the implementation changes, the exact signature and usage of `findValidCollateralClaim` within the logic might differ from the attached version.*
- **`SMARTCollateral.sol`**: The standard (non-upgradeable) implementation. It inherits `_SMARTCollateralLogic` and integrates the check into the `_beforeMint` hook of a standard SMART token.
- **`SMARTCollateralUpgradeable.sol`**: The upgradeable implementation. It inherits `_SMARTCollateralLogic`, is `Initializable`, and integrates the check into the `_beforeMint` hook of an upgradeable SMART token.

## Features

- **Global Collateral Verification**: Automatically checks for a single, valid collateral claim on the **token's identity** before allowing minting.
- **Claim Validation**: Verifies claim topic, issuer trust, issuer validity (`isClaimValid`), data decoding, and expiry.
- **Global Supply Cap**: Ensures the collateral amount specified in the claim is greater than or equal to the projected total token supply *after* the mint.
- **Hook Integration**: Leverages the `_beforeMint` hook from `SMARTHooks` to seamlessly integrate the check into the minting process.
- **Configurable Topic**: The specific ERC-735 claim topic representing the global collateral is configured during initialization.
- **Standard & Upgradeable**: Provides both standard and upgradeable versions.

## Usage

To use this extension:

1. **Inherit the Base Extension**: Choose either `SMARTCollateral` (for standard contracts) or `SMARTCollateralUpgradeable` (for upgradeable contracts) and inherit it in your main SMART token contract.
2. **Inherit Core SMART & ERC20**: Ensure your main contract also inherits the corresponding core SMART implementation (`SMART` or `SMARTUpgradeable`) and ERC20 implementation (`ERC20` or `ERC20Upgradeable`). These provide necessary functions like `totalSupply`, `onchainID`, `identityRegistry`, and the `_beforeMint` hook framework.
3. **Implement Constructor/Initializer**:
    - **Standard (`SMARTCollateral`)**: In the final contract's `constructor`, call parent constructors, including passing the `collateralProofTopic_` to the `SMARTCollateral` constructor (which calls `_SMARTCollateral_init`).
    - **Upgradeable (`SMARTCollateralUpgradeable`)**: In the final contract's `initialize` function, call initializers for parent contracts (e.g., `__ERC20_init`, `__SMARTUpgradeable_init`) and then call `__SMARTCollateralUpgradeable_init(collateralProofTopic_)`.

## Collateral Claim Requirements

For any mint operation to succeed, the following conditions must be met regarding a **single, global claim held on the token contract's own identity contract** (`this.onchainID()`):

1. **Claim Existence & Identification**: The token's identity contract must hold a claim whose topic matches the configured `collateralProofTopic`. The specific `claimId` used to fetch this claim is likely derived from the token's identity address and the topic (e.g., `keccak256(abi.encodePacked(this.onchainID(), collateralProofTopic))`).
2. **Trusted Issuer**: The issuer of this global collateral claim must be registered as a trusted issuer for the `collateralProofTopic` within the `IERC3643TrustedIssuersRegistry` linked by the `ISMARTIdentityRegistry`.
3. **Issuer Validation**: The trusted issuer contract itself must confirm the claim is valid when its `isClaimValid(tokenIdentity, topic, signature, data)` function is called (where `tokenIdentity` is the address returned by `this.onchainID()`).
4. **Claim Data**: The `data` field of the claim must be ABI-encoded as `(uint256 amount, uint256 expiryTimestamp)`.
5. **Expiry**: The `expiryTimestamp` decoded from the claim data must be in the future (`expiryTimestamp > block.timestamp`).
6. **Sufficient Amount (Global Cap)**: The `amount` decoded from the claim data must be greater than or equal to the token's `totalSupply()` plus the `amount` being minted (`collateralAmount >= totalSupply() + mintAmount`). This `collateralAmount` acts as a global maximum total supply for the token contract.

The collateral check logic (within `_collateral_beforeMintLogic`) verifies these conditions by looking up this specific global claim on the token's identity and validating it against the trusted issuers list.

## Authorization

This extension does not manage minting permissions itself. It acts as a check *within* the minting process. The authorization for *who* can call the `mint` function is handled by other parts of the SMART token implementation (e.g., Minter Role in `SMARTMintableAccessControlAuthorization`).

## Security Considerations

- **Trusted Issuers**: The security of the collateral check relies heavily on the integrity and security of the configured trusted issuers and the `IERC3643TrustedIssuersRegistry`. Only genuinely trustworthy entities should be added as trusted issuers for the collateral topic.
- **Issuer `isClaimValid` Logic**: The logic within the trusted issuer's `isClaimValid` function is critical. It should correctly verify signatures and handle claim revocation.
- **Claim Data Integrity**: Ensure that the process for generating and signing the global collateral claim data `(amount, expiryTimestamp)` is secure to prevent tampering.
- **Claim Management**: A mechanism is needed to initially add and subsequently update/remove this global collateral claim on the token's identity as needed. This is outside the scope of the extension itself.
- **Topic ID Configuration**: The `collateralProofTopic` must be set correctly during initialization. An incorrect topic ID will prevent any minting that relies on this check.
- **Gas Costs**: The collateral check function involves multiple external calls (to identity registry, issuers registry, identity contract, issuer contract). This can incur significant gas costs. Consider the gas implications for minting operations.
