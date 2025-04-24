// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// Base modules
import { AbstractCountryComplianceModule } from "./AbstractCountryComplianceModule.sol";

/**
 * @title CountryBlockListComplianceModule
 * @notice Compliance module to restrict transfers based on a blocklist of countries
 * @dev Parameters format: abi.encode(uint16[] blockedCountries)
 */
contract CountryBlockListComplianceModule is AbstractCountryComplianceModule {
    /**
     * @dev Validates if a transfer can occur based on blocklist country restrictions
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
        // Decode parameters to get blocked countries
        uint16[] memory blockedCountries = _decodeParams(_params);

        // Get receiver's country from the identity registry
        (bool hasIdentity, uint16 receiverCountry) = _getUserCountry(_token, _to);

        // Allow transfer if user has no identity registered
        if (!hasIdentity) {
            return;
        }

        // Check if the receiver's country is in the blocked list
        for (uint256 i = 0; i < blockedCountries.length; i++) {
            if (blockedCountries[i] == receiverCountry) {
                revert ComplianceCheckFailed("Receiver country is blocked");
            }
        }

        // Country not in the block list, allow the transfer
    }

    /**
     * @dev Returns the module name
     */
    function name() external pure override returns (string memory) {
        return "Country BlockList Compliance Module";
    }
}
