// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../interface/ISMART.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { SMARTHooks } from "./SMARTHooks.sol";

/// @title SMARTBurnable
/// @notice Extension that adds burnable functionality to SMART tokens
abstract contract SMARTBurnable is ERC20Burnable, SMARTHooks, ISMART {
    /// @notice Burns a specific amount of tokens from a user's address
    /// @param _userAddress The address to burn tokens from
    /// @param _amount The amount of tokens to burn
    function burn(address _userAddress, uint256 _amount) public virtual {
        _validateBurn(_userAddress, _amount);
        _burn(_userAddress, _amount);
        _afterBurn(_userAddress, _amount);
    }

    /// @notice Burns tokens from multiple addresses in a single transaction
    /// @param _userAddresses The addresses to burn tokens from
    /// @param _amounts The amounts of tokens to burn from each address
    function batchBurn(address[] calldata _userAddresses, uint256[] calldata _amounts) public virtual {
        require(_userAddresses.length == _amounts.length, "Length mismatch");
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            _validateBurn(_userAddresses[i], _amounts[i]);
            _burn(_userAddresses[i], _amounts[i]);
            _afterBurn(_userAddresses[i], _amounts[i]);
        }
    }

    /// @dev Internal validation hook for burning tokens.
    function _validateBurn(address _from, uint256 _amount) internal virtual override {
        super._validateBurn(_from, _amount);
    }
}
