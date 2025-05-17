// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Identity } from "@onchainid/contracts/Identity.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

// TODO: fix to be ERC-2771 compatible
// TODO: fix to be ERC-165 initialization
contract SMARTIdentityImplementation is Identity, ERC165Upgradeable {
    constructor() Identity(address(0), true) { }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IIdentity).interfaceId || interfaceId == type(IERC165).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
