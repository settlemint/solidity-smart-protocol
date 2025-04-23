// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

abstract contract _SMARTAuthorizationHooks {
    function _auhtorizeUpdateTokenSettings() internal view virtual returns (bool);
    function _authorizeUpdateComplianceSettings() internal view virtual returns (bool);
    function _authorizeUpdateVerificationSettings() internal view virtual returns (bool);
    function _authorizeMintToken() internal view virtual returns (bool);
}
