    // SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

/// @notice Represents a pair of a compliance module address and its associated configuration parameters.
struct SMARTComplianceModuleParamPair {
    address module;
    bytes params;
}
