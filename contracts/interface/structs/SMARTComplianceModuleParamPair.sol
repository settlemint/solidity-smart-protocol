    // SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @notice Represents a pair of a compliance module address and its associated configuration parameters.
struct SMARTComplianceModuleParamPair {
    address module;
    bytes params;
}
