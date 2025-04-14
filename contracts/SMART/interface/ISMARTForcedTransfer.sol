// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "./ISMART.sol";

/// @title ISMARTForcedTransfer
/// @notice Interface for SMART tokens with forced transfer functionality
interface ISMARTForcedTransfer is ISMART {
    /// Functions
    function forcedTransfer(address _from, address _to, uint256 _amount) external returns (bool);
    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    )
        external;
}
