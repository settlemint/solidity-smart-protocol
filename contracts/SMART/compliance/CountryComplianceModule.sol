// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMARTComplianceModule } from "../interface/ISMARTComplianceModule.sol";
import { ISMART } from "../interface/ISMART.sol";
import { ISMARTIdentityRegistry } from "../interface/ISMARTIdentityRegistry.sol";

/**
 * @title CountryComplianceModule
 * @notice Compliance module to restrict transfers based on user countries
 * @dev Parameters format: abi.encode(uint16[] allowedCountries)
 */
contract CountryComplianceModule is ISMARTComplianceModule {
    /**
     * @dev Validates if a transfer can occur based on country restrictions
     * @param _token Address of the token
     * @param _to Address of the transfer receiver
     * @param _params Token-specific parameters for this module
     */
    function canTransfer(
        address _token,
        address,
        address _to,
        uint256,
        bytes calldata _params
    )
        external
        view
        override
    {
        // Decode parameters to get allowed countries
        uint16[] memory allowedCountries = _decodeParams(_params);

        // Unused parameters: _from, _value

        // Get the identity registry from the token
        ISMARTIdentityRegistry identityRegistry = ISMART(_token).identityRegistry();

        // Check if receiver has an identity in the registry
        if (!identityRegistry.contains(_to)) {
            return; // Allow transfer if user has no identity registered
        }

        // Get receiver's country from the identity registry
        uint16 receiverCountry = identityRegistry.investorCountry(_to);

        // Check if the receiver's country is in the allowed list
        bool isAllowed = false;
        for (uint256 i = 0; i < allowedCountries.length; i++) {
            if (allowedCountries[i] == receiverCountry) {
                isAllowed = true;
                break;
            }
        }

        if (!isAllowed) {
            revert ComplianceCheckFailed("Receiver country not allowed");
        }
    }

    /**
     * @dev Records a transfer action
     */
    function transferred(
        address _token,
        address _from,
        address _to,
        uint256 _value,
        bytes calldata _params
    )
        external
        override
    { }

    /**
     * @dev Records a mint action
     */
    function created(address _token, address _to, uint256 _value, bytes calldata _params) external override { }

    /**
     * @dev Records a burn action
     */
    function destroyed(address _token, address _from, uint256 _value, bytes calldata _params) external override { }

    /**
     * @dev Validates the format of module parameters
     * @param _params The encoded parameters to validate
     */
    function validateParameters(bytes calldata _params) external pure override {
        // Decode parameters and perform validation
        uint16[] memory countries = _decodeParams(_params);

        // Additional validation logic
        if (countries.length == 0) {
            revert InvalidParameters("At least one country code is required");
        }
    }

    /**
     * @dev Returns the module name
     */
    function name() external pure override returns (string memory) {
        return "Country Compliance Module";
    }

    /**
     * @dev Helper function to validate parameter decoding
     * @param _params The encoded parameters
     * @return The decoded country codes
     */
    function _decodeParams(bytes calldata _params) private pure returns (uint16[] memory) {
        return abi.decode(_params, (uint16[]));
    }
}
