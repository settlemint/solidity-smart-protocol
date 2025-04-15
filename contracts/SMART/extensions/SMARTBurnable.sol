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
        require(balanceOf(_userAddress) >= _amount, "Insufficient balance");
        _burn(_userAddress, _amount);
    }

    /// @notice Burns tokens from multiple addresses in a single transaction
    /// @param _userAddresses The addresses to burn tokens from
    /// @param _amounts The amounts of tokens to burn from each address
    function batchBurn(address[] calldata _userAddresses, uint256[] calldata _amounts) public virtual {
        require(_userAddresses.length == _amounts.length, "Length mismatch");
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            require(balanceOf(_userAddresses[i]) >= _amounts[i], "Insufficient balance");
            burn(_userAddresses[i], _amounts[i]);
        }
    }
}
