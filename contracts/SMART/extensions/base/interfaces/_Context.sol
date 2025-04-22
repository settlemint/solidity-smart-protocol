// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

abstract contract _Context {
    function _msgSender() internal view virtual returns (address);

    function _msgData() internal view virtual returns (bytes calldata);
}
