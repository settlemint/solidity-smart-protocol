// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMARTBatch } from "../interface/ISMARTBatch.sol";
import { ISMART } from "../interface/ISMART.sol";
import { ISMARTFreezable } from "../interface/ISMARTFreezable.sol";

/// @title SMARTBatch
/// @notice Extension that adds batch operations to SMART tokens
abstract contract SMARTBatch is ISMARTBatch, ISMARTFreezable {
    /// @inheritdoc ISMARTBatch
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) public virtual override {
        require(_toList.length == _amounts.length, "Length mismatch");
        for (uint256 i = 0; i < _toList.length; i++) {
            transfer(_toList[i], _amounts[i]);
        }
    }

    /// @inheritdoc ISMARTBatch
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
            uint256 frozenTokens = getFrozenTokens(_fromList[i]);
            if (frozenTokens > 0) {
                unfreezePartialTokens(_fromList[i], frozenTokens);
            }
            transferFrom(_fromList[i], _toList[i], _amounts[i]);
        }
    }

    /// @inheritdoc ISMARTBatch
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) public virtual override {
        require(_toList.length == _amounts.length, "Length mismatch");
        for (uint256 i = 0; i < _toList.length; i++) {
            _mint(_toList[i], _amounts[i]);
        }
    }
}
