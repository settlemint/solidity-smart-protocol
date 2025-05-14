// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { _SMARTExtension } from "./../../common/_SMARTExtension.sol";
import { SMARTHooks } from "./../../common/SMARTHooks.sol";
import { ISMARTYield } from "./../ISMARTYield.sol";
import { ISMARTYieldSchedule } from "./../schedules/ISMARTYieldSchedule.sol";
import { ZeroAddressNotAllowed } from "./../../common/CommonErrors.sol";
import { YieldScheduleAlreadySet, YieldScheduleActive } from "./../SMARTYieldErrors.sol";
import { YieldScheduleSet } from "./../SMARTYieldEvents.sol";

/// @title Internal Logic for SMART Yield Extension
/// @notice Base contract containing the core logic and event for yield management.
/// @dev This abstract contract provides the `setYieldSchedule` function, which allows a token holder to set the yield
/// schedule.
abstract contract _SMARTYieldLogic is _SMARTExtension, ISMARTYield {
    /// @notice The yield schedule contract for this token
    address public yieldSchedule;

    // -- Initializer --
    function __SMARTYield_init_unchained() internal {
        _registerInterface(type(ISMARTYield).interfaceId);
    }

    // -- Internal Implementation for SMARTYueld interface functions --

    /// @notice Sets the yield schedule for this token
    /// @dev Reverts if the schedule is invalid or already set
    /// @param schedule The address of the yield schedule contract
    function _smart_setYieldSchedule(address schedule) internal {
        if (schedule == address(0)) revert ZeroAddressNotAllowed();
        if (yieldSchedule != address(0)) revert YieldScheduleAlreadySet();

        yieldSchedule = schedule;
        emit YieldScheduleSet(_smartSender(), schedule);
    }

    // -- Internal Hook Helper Functions --

    /// @notice Internal logic executed before a mint operation to check if the yield schedule has started
    /// @dev Called by the implementing contract's `_beforeMint` hook.
    function __yield_beforeMintLogic() internal view virtual {
        if (yieldSchedule != address(0)) {
            // Use the interface to call the external contract
            // Revert if the yield schedule has already started
            if (ISMARTYieldSchedule(yieldSchedule).startDate() <= block.timestamp) {
                revert YieldScheduleActive();
            }
        }
    }
}
