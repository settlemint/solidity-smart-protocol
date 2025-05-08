// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// Base modules
import { AbstractCountryComplianceModule } from "./AbstractCountryComplianceModule.sol";

// Interface imports
import { ISMARTComplianceModule } from "../interface/ISMARTComplianceModule.sol"; // Needed for @inheritdoc

/**
 * @title Country AllowList Compliance Module
 * @notice Compliance module restricting transfers TO users whose country is NOT in the combined allowlist.
 * @dev Combines a global allowlist (managed within this specific module instance via `GLOBAL_LIST_MANAGER_ROLE`)
 *      with a token-specific list of additional allowed countries provided via parameters.
 *      Transfers are allowed if the receiver's country is in either the global list OR the token-specific list.
 *      If the receiver has no identity or country, the transfer is implicitly allowed by this module.
 * @custom:parameters Standard format: `abi.encode(uint16[] memory additionalAllowedCountries)`
 */
contract CountryAllowListComplianceModule is AbstractCountryComplianceModule {
    // --- State Variables ---
    /// @notice Mapping storing the global allowlist for this module instance (country code => allowed status).
    mapping(uint16 => bool) private _globalAllowedCountries;

    // --- Events ---
    /// @notice Emitted when countries are added to or removed from the global allowlist of this module instance.
    event GlobalAllowedCountriesUpdated(uint16[] countries, bool allowed);

    // --- Global Allow List Management (Manager Role Only) ---

    /**
     * @notice Adds or removes countries from the global allowlist specific to this module instance.
     * @dev Requires the caller to have the `GLOBAL_LIST_MANAGER_ROLE`.
     * @param _countries Array of country codes (ISO 3166-1 numeric).
     * @param _allow `true` to add countries to the global allowlist, `false` to remove them.
     */
    function setGlobalAllowedCountries(
        uint16[] calldata _countries,
        bool _allow
    )
        external
        onlyRole(GLOBAL_LIST_MANAGER_ROLE)
    {
        for (uint256 i = 0; i < _countries.length; i++) {
            _globalAllowedCountries[_countries[i]] = _allow;
        }
        emit GlobalAllowedCountriesUpdated(_countries, _allow);
    }

    // --- Views ---

    /**
     * @notice Checks if a country code is present in the global allowlist of this module instance.
     * @param _country The country code (ISO 3166-1 numeric) to check.
     * @return True if the country is globally allowed by this module, false otherwise.
     */
    function isGloballyAllowed(uint16 _country) public view returns (bool) {
        return _globalAllowedCountries[_country];
    }

    // --- Compliance Check --- (ISMARTComplianceModule Implementation)

    /**
     * @inheritdoc ISMARTComplianceModule
     * @dev Checks if a transfer is allowed based on the receiver's country.
     *      Allows the transfer if:
     *      1. The receiver has no registered identity or country code.
     *      2. The receiver's country is in this module's global allowlist.
     *      3. The receiver's country is in the token-specific additional allowed countries list (`_params`).
     *      Reverts with `ComplianceCheckFailed` if none of the above conditions are met.
     * @param _token Address of the ISMART token contract.
     * @param _to Address of the receiver.
     * @param _params ABI-encoded `uint16[]` of additional allowed country codes specific to the token.
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
        (bool hasIdentity, uint16 receiverCountry) = _getUserCountry(_token, _to);

        // Condition 1: If no identity/country, allow transfer (cannot enforce allowlist)
        if (!hasIdentity || receiverCountry == 0) {
            return;
        }

        // Condition 2: Check this module's global allow list
        if (isGloballyAllowed(receiverCountry)) {
            return; // Allowed globally by this module
        }

        // Condition 3: Check token-specific additional allowed countries
        uint16[] memory additionalAllowedCountries = _decodeParams(_params); // Decodes uint16[]
        for (uint256 i = 0; i < additionalAllowedCountries.length; i++) {
            if (additionalAllowedCountries[i] == receiverCountry) {
                return; // Allowed specifically for this token
            }
        }

        // If none of the allow conditions were met
        revert ComplianceCheckFailed("Receiver country not in allowlist");
    }

    // --- Module Info --- (ISMARTComplianceModule Implementation)

    /**
     * @inheritdoc ISMARTComplianceModule
     */
    function name() external pure override returns (string memory) {
        return "Country AllowList Compliance Module";
    }
}
