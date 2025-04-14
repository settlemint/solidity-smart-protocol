// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ISMARTBurnable } from "../interface/ISMARTBurnable.sol";
import { ISMART } from "../interface/ISMART.sol";

/// @title SMARTBurnable
/// @notice Extension that adds burnable functionality to SMART tokens
abstract contract SMARTBurnable is ERC20Burnable, ISMARTBurnable {
    /// @inheritdoc ISMARTBurnable
    function burn(address _userAddress, uint256 _amount) public virtual override {
        _burn(_userAddress, _amount);
    }

    /// @inheritdoc ISMARTBurnable
    function batchBurn(address[] calldata _userAddresses, uint256[] calldata _amounts) public virtual override {
        require(_userAddresses.length == _amounts.length, "Length mismatch");
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            burn(_userAddresses[i], _amounts[i]);
        }
    }
}
