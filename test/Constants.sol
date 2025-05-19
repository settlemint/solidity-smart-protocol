// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title TestConstants
 * @notice Defines constants used across the SMART protocol test suite.
 */
library TestConstants {
    // Claim Topics
    uint256 public constant CLAIM_TOPIC_KYC = 1;
    uint256 public constant CLAIM_TOPIC_AML = 2;
    uint256 public constant CLAIM_TOPIC_COLLATERAL = 3;

    // Country Codes (ISO 3166-1 numeric)
    uint16 public constant COUNTRY_CODE_BE = 56;
    uint16 public constant COUNTRY_CODE_JP = 392;
    uint16 public constant COUNTRY_CODE_US = 840;

    // Roles
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
}
