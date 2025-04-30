// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

error InvalidDecimals(uint8 decimals);
error DuplicateModule(address module);
error MintNotCompliant();
error TransferNotCompliant();
error ModuleAlreadyAdded();
error ModuleNotFound();
error CannotRecoverSelf();
error InsufficientTokenBalance();
