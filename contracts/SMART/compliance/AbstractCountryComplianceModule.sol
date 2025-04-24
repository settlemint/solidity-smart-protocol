// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// Interface imports
import { ISMART } from "../interface/ISMART.sol";
import { ISMARTIdentityRegistry } from "../interface/ISMARTIdentityRegistry.sol";

// Base modules
import { AbstractComplianceModule } from "./AbstractComplianceModule.sol";

/**
 * @title AbstractCountryComplianceModule
 * @notice Base abstract contract for country-based compliance modules
 * @dev Parameters format: abi.encode(uint16[] countries)
 */
abstract contract AbstractCountryComplianceModule is AbstractComplianceModule {
    /**
     * @dev Validates the format of module parameters
     * @param _params The encoded parameters to validate
     */
    function validateParameters(bytes calldata _params) external pure virtual override {
        // Decode parameters and perform validation
        uint16[] memory countries = _decodeParams(_params);

        // Additional validation logic
        if (countries.length == 0) {
            revert InvalidParameters("At least one country code is required");
        }
    }

    /**
     * @dev Helper function to validate parameter decoding
     * @param _params The encoded parameters
     * @return The decoded country codes
     */
    function _decodeParams(bytes calldata _params) internal pure returns (uint16[] memory) {
        return abi.decode(_params, (uint16[]));
    }

    /**
     * @dev Helper function to get a user's country from the identity registry
     * @param _token Address of the token
     * @param _user Address of the user
     * @return (bool hasIdentity, uint16 country) Tuple indicating if user has identity and their country
     */
    function _getUserCountry(address _token, address _user) internal view returns (bool, uint16) {
        // Get the identity registry from the token
        ISMARTIdentityRegistry identityRegistry = ISMART(_token).identityRegistry();

        // Check if user has an identity in the registry
        if (!identityRegistry.contains(_user)) {
            return (false, 0); // No identity registered
        }

        // Get user's country from the identity registry
        uint16 country = identityRegistry.investorCountry(_user);
        return (true, country);
    }
}
