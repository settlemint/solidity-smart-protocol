# SMART Compliance Modules

This directory contains compliance modules designed to work with the main `SMARTCompliance` contract and `ISMART` tokens.

Compliance modules enforce specific rules on token transfers, minting, and burning based on various criteria. They are registered with a `SMARTCompliance` contract instance, which in turn is associated with one or more `ISMART` tokens.

Each module interacts with the `SMARTCompliance` contract via the `ISMARTComplianceModule` interface.

## Modules

### `CountryAllowListComplianceModule`

**Description**: Restricts transfers TO users whose country is NOT in the combined allowlist. Combines a module-instance-specific global allowlist (managed via `GLOBAL_LIST_MANAGER_ROLE`) with a token-specific list provided via parameters. Allows transfers if the receiver's country is in either list or if the receiver has no identity/country.

**Features**:

* Global Allowlist (Module Instance)
* Token-Specific Additional Allowed Countries

**Parameters Format**: The parameters should be ABI-encoded as a dynamic array of uint16 country codes: `abi.encode(uint16[] memory additionalAllowedCountries)`.

```solidity
// Example: Allow Belgium (numeric code 100) and Japan (200) specifically for this token
uint16[] memory tokenSpecificAllowed = new uint16[](2);
tokenSpecificAllowed[0] = 100; // BE
tokenSpecificAllowed[1] = 200; // JP
bytes memory params = abi.encode(tokenSpecificAllowed);

// Use 'params' when calling myToken.addComplianceModule(address(allowListModule), params);
```

### `CountryBlockListComplianceModule`

**Description**: Restricts transfers TO users whose country IS in the combined blocklist. Combines a module-instance-specific global blocklist (managed via `GLOBAL_LIST_MANAGER_ROLE`) with a token-specific list provided via parameters. Blocks transfers if the receiver's country is in either list. Allows transfers implicitly if the receiver has no identity/country or is not in any blocklist.

**Features**:

* Global Blocklist (Module Instance)
* Token-Specific Additional Blocked Countries

**Parameters Format**: The parameters should be ABI-encoded as a dynamic array of uint16 country codes: `abi.encode(uint16[] memory additionalBlockedCountries)`.

```solidity
// Example: Block Russia (numeric code 500) and China (600) specifically for this token
uint16[] memory tokenSpecificBlocked = new uint16[](2);
tokenSpecificBlocked[0] = 500; // RU
tokenSpecificBlocked[1] = 600; // CN
bytes memory params = abi.encode(tokenSpecificBlocked);

// Use 'params' when calling myToken.addComplianceModule(address(blockListModule), params);
```

## General Usage Steps

1. Deploy the specific compliance module contract(s) you need.
2. Deploy the main `SMARTCompliance` contract if you haven't already.
3. Deploy your `ISMART` token contract, configuring it to use the deployed `SMARTCompliance` contract address during initialization.
4. Prepare the ABI-encoded parameters for the module as shown in the examples above.
5. Add the module instance to your token via `myToken.addComplianceModule(moduleAddress, encodedParams)` (requires token admin role).
