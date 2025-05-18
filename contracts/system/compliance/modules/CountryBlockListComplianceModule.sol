// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// Base modules
import { AbstractCountryComplianceModule } from "./AbstractCountryComplianceModule.sol";

// Interface imports
import { ISMARTComplianceModule } from "../../../interface/ISMARTComplianceModule.sol"; // Needed for @inheritdoc

/**
 * @title Country BlockList Compliance Module
 * @notice Compliance module restricting transfers TO users whose country IS in the combined blocklist.
 * @dev Combines a global blocklist (managed within this specific module instance via `GLOBAL_LIST_MANAGER_ROLE`)
 *      with a token-specific list of additional blocked countries provided via parameters.
 *      Transfers are blocked if the receiver's country is in either the global list OR the token-specific list.
 *      If the receiver has no identity or country, the transfer is implicitly allowed (not blocked) by this module.
 * @custom:parameters Standard format: `abi.encode(uint16[] memory additionalBlockedCountries)`
 */
contract CountryBlockListComplianceModule is AbstractCountryComplianceModule {
    // --- State Variables ---
    /// @notice Mapping storing the global blocklist for this module instance (country code => blocked status).
    mapping(uint16 => bool) private _globalBlockedCountries;

    // --- Events ---
    /// @notice Emitted when countries are added to or removed from the global blocklist of this module instance.
    event GlobalBlockedCountriesUpdated(uint16[] countries, bool blocked);

    // --- Global Block List Management (Manager Role Only) ---

    /**
     * @notice Adds or removes countries from the global blocklist specific to this module instance.
     * @dev Requires the caller to have the `GLOBAL_LIST_MANAGER_ROLE`.
     * @param _countries Array of country codes (ISO 3166-1 numeric).
     * @param _block `true` to add countries to the global blocklist, `false` to remove them.
     */
    function setGlobalBlockedCountries(
        uint16[] calldata _countries,
        bool _block
    )
        external
        onlyRole(GLOBAL_LIST_MANAGER_ROLE)
    {
        uint256 countriesLength = _countries.length;
        for (uint256 i = 0; i < countriesLength;) {
            _globalBlockedCountries[_countries[i]] = _block;
            unchecked {
                ++i;
            }
        }
        emit GlobalBlockedCountriesUpdated(_countries, _block);
    }

    // --- Views ---

    /**
     * @notice Checks if a country code is present in the global blocklist of this module instance.
     * @param _country The country code (ISO 3166-1 numeric) to check.
     * @return True if the country is globally blocked by this module, false otherwise.
     */
    function isGloballyBlocked(uint16 _country) public view returns (bool) {
        return _globalBlockedCountries[_country];
    }

    // --- Compliance Check --- (ISMARTComplianceModule Implementation)

    /**
     * @inheritdoc ISMARTComplianceModule
     * @dev Checks if a transfer should be blocked based on the receiver's country.
     *      Blocks the transfer (reverts) if:
     *      1. The receiver has a registered identity and country code AND
     *      2. The receiver's country is in this module's global blocklist OR
     *      3. The receiver's country is in the token-specific additional blocked countries list (`_params`).
     *      Allows the transfer implicitly if the receiver has no identity/country or is not in any blocklist.
     * @param _token Address of the ISMART token contract.
     * @param _to Address of the receiver.
     * @param _params ABI-encoded `uint16[]` of additional blocked country codes specific to the token.
     */
    function canTransfer(
        address _token,
        address, /* _from */
        address _to,
        uint256, /* _value */
        bytes calldata _params
    )
        external
        view
        override // Overrides AbstractComplianceModule.canTransfer
    {
        (bool hasIdentity, uint16 receiverCountry) = _getUserCountry(_to, _token);

        // Condition 1: Only apply blocklist if identity and country are known
        if (!hasIdentity || receiverCountry == 0) {
            return; // Cannot enforce blocklist, so allow
        }

        // Condition 2: Check this module's global block list
        if (isGloballyBlocked(receiverCountry)) {
            revert ComplianceCheckFailed("Receiver country globally blocked");
        }

        // Condition 3: Check token-specific additional blocked countries
        uint16[] memory additionalBlockedCountries = _decodeParams(_params); // Decodes uint16[]
        uint256 additionalBlockedCountriesLength = additionalBlockedCountries.length;
        for (uint256 i = 0; i < additionalBlockedCountriesLength;) {
            if (additionalBlockedCountries[i] == receiverCountry) {
                revert ComplianceCheckFailed("Receiver country blocked for token");
            }
            unchecked {
                ++i;
            }
        }

        // If not blocked by global or token-specific list, allow implicitly
    }

    // --- Module Info --- (ISMARTComplianceModule Implementation)

    /**
     * @inheritdoc ISMARTComplianceModule
     */
    function name() external pure override returns (string memory) {
        return "Country BlockList Compliance Module";
    }
}
