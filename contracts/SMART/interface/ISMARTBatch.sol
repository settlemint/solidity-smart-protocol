// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "./ISMART.sol";

/// @title ISMARTBatch
/// @notice Interface for SMART tokens with batch operations
interface ISMARTBatch is ISMART {
    /// Functions
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external;
    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    )
        external;
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) external;
}
