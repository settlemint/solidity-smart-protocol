// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { AbstractCountryComplianceModule } from "./AbstractCountryComplianceModule.sol";

/**
 * @title CountryAllowListComplianceModule
 * @notice Compliance module to restrict transfers based on an allowlist of countries
 * @dev Parameters format: abi.encode(uint16[] allowedCountries)
 */
contract CountryAllowListComplianceModule is AbstractCountryComplianceModule {
    /**
     * @dev Validates if a transfer can occur based on allowlist country restrictions
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

        // Get receiver's country from the identity registry
        (bool hasIdentity, uint16 receiverCountry) = _getUserCountry(_token, _to);

        // Allow transfer if user has no identity registered
        if (!hasIdentity) {
            return;
        }

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
     * @dev Returns the module name
     */
    function name() external pure override returns (string memory) {
        return "Country AllowList Compliance Module";
    }
}
