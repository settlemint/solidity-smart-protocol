// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../interface/ISMART.sol";

/// @title SMARTForcedTransfer
/// @notice Extension that adds forced transfer functionality to SMART tokens
abstract contract SMARTForcedTransfer is ISMART {
    /// @inheritdoc ISMARTForcedTransfer
    function forcedTransfer(address _from, address _to, uint256 _amount) public virtual override returns (bool) {
        uint256 frozenTokens = getFrozenTokens(_from);
        if (frozenTokens > 0) {
            unfreezePartialTokens(_from, frozenTokens);
        }
        _transfer(_from, _to, _amount);
        return true;
    }

    /// @inheritdoc ISMARTForcedTransfer
    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    )
        public
        virtual
        override
    {
        require(_fromList.length == _toList.length && _toList.length == _amounts.length, "Length mismatch");
        for (uint256 i = 0; i < _fromList.length; i++) {
            forcedTransfer(_fromList[i], _toList[i], _amounts[i]);
        }
    }
}
