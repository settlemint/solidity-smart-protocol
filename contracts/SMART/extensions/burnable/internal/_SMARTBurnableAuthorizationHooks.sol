// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

abstract contract _SMARTBurnableAuthorizationHooks {
    function _authorizeBurn() internal view virtual returns (bool);
}
