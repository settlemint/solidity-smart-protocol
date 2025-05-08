// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

// OpenZeppelin imports
// AccessControl is inherited from AbstractComplianceModule

// Interface imports
import { ISMART } from "../interface/ISMART.sol";
import { ISMARTIdentityRegistry } from "../interface/ISMARTIdentityRegistry.sol";
import { ISMARTComplianceModule } from "../interface/ISMARTComplianceModule.sol"; // Needed for @inheritdoc

// Base modules
import { AbstractComplianceModule } from "./AbstractComplianceModule.sol";

/**
 * @title Abstract Country Compliance Module Base
 * @notice Provides common functionality and helpers for compliance modules based on investor country.
 * @dev Inherits from `AbstractComplianceModule`. Requires inheriting contracts to implement
 *      specific country list logic (e.g., allowlist, blocklist) within the `canTransfer` function.
 *      Defines a standard parameter format (`uint16[]`) for token-specific country lists
 *      and provides a `GLOBAL_LIST_MANAGER_ROLE` for managing potential global lists within inheriting modules.
 */
abstract contract AbstractCountryComplianceModule is AbstractComplianceModule {
    // --- Roles ---
    /**
     * @notice Role intended for managing a global country list within inheriting module instances.
     * @dev Grant this role to addresses that should be able to modify the module's own shared list (if any).
     */
    bytes32 public constant GLOBAL_LIST_MANAGER_ROLE = keccak256("GLOBAL_LIST_MANAGER_ROLE");

    // --- Constructor ---
    /**
     * @dev Grants the deployer the `DEFAULT_ADMIN_ROLE` (via AbstractComplianceModule)
     *      and the `GLOBAL_LIST_MANAGER_ROLE` specific to country list management.
     */
    constructor() AbstractComplianceModule() {
        _grantRole(GLOBAL_LIST_MANAGER_ROLE, _msgSender());
    }

    // --- Parameter Validation --- (Standard for Country Modules)

    /**
     * @inheritdoc ISMARTComplianceModule
     * @dev Validates the standard parameter format for country-based modules.
     *      Expects parameters to be `abi.encode(uint16[])`.
     *      Reverts if decoding fails.
     * @param _params The ABI-encoded parameters (`uint16[]`) to validate.
     */
    function validateParameters(bytes calldata _params) public view virtual override {
        // Attempt to decode parameters as an array of uint16. Reverts if format is incorrect.
        abi.decode(_params, (uint16[]));
        // Note: Doesn't validate country codes themselves, only the format.
    }

    // --- Internal Helper Functions ---

    /**
     * @dev Decodes the standard token-specific country list parameters.
     * @param _params The ABI-encoded parameters (`abi.encode(uint16[])`).
     * @return additionalCountries The decoded array of additional country codes.
     */
    function _decodeParams(bytes calldata _params) internal pure returns (uint16[] memory additionalCountries) {
        // Assumes validateParameters has already been checked by the ISMART token before storing.
        return abi.decode(_params, (uint16[]));
    }

    /**
     * @dev Retrieves a user's registered country code from the identity registry linked to the given SMART token.
     * @param _token Address of the ISMART token contract.
     * @param _user Address of the user whose country is needed.
     * @return hasIdentity True if the user has a registered identity, false otherwise.
     * @return country The user's registered country code (ISO 3166-1 numeric), or 0 if no identity or not set.
     */
    function _getUserCountry(address _token, address _user) internal view returns (bool hasIdentity, uint16 country) {
        // Get the registry associated with this specific token instance
        ISMARTIdentityRegistry identityRegistry = ISMART(_token).identityRegistry();

        // Check if the user is registered in that specific registry
        // Use a direct external call to `contains` for clarity
        hasIdentity = identityRegistry.contains(_user);
        if (!hasIdentity) {
            return (false, 0);
        }

        // If registered, get the country code
        country = identityRegistry.investorCountry(_user);
        return (true, country);
    }
}
