// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.27;

import { Identity } from "../onchainid/Identity.sol";
import { IIdentity } from "../onchainid/interface/IIdentity.sol";
import { IERC734 } from "../onchainid/interface/IERC734.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

error ZeroAddressNotAllowed();
error AlreadyAFactory();
error NotAFactory();
error EmptyString();
error SaltAlreadyTaken();
error WalletAlreadyLinked();
error EmptyKeysList();
error WalletInManagementKeys();
error TokenAlreadyLinked();
error OnlyFactoryOrOwnerCanCall();

contract SMARTIdentityFacory is Ownable {
    address private immutable _identityImplementation;

    mapping(string => bool) private _saltTaken;
    mapping(address => bool) private _identities;
    mapping(address => address) private _tokenIdentities;

    event IdentityCreated(address indexed identity, address indexed wallet);
    event TokenIdentityCreated(address indexed identity, address indexed token);

    constructor() Ownable(_msgSender()) {
        _identityImplementation = address(new Identity(address(0), true));
    }

    function createIdentity(address _wallet, bytes32[] memory _managementKeys) external onlyOwner returns (address) {
        if (_wallet == address(0)) revert ZeroAddressNotAllowed();

        string memory salt = string.concat("OID", Strings.toHexString(_wallet));
        if (_saltTaken[salt]) revert SaltAlreadyTaken();

        address identity = _deployIdentity(salt, _wallet);
        _saltTaken[salt] = true;

        // Add management keys if provided
        if (_managementKeys.length > 0) {
            for (uint256 i = 0; i < _managementKeys.length; i++) {
                if (_managementKeys[i] == keccak256(abi.encode(_wallet))) {
                    revert WalletInManagementKeys();
                }
                IERC734(identity).addKey(_managementKeys[i], 1, 1);
            }
        }

        _tokenIdentities[_wallet] = identity;

        emit IdentityCreated(identity, _wallet);
        return identity;
    }

    function createTokenIdentity(address _token, address _tokenOwner) external onlyOwner returns (address) {
        if (_token == address(0)) revert ZeroAddressNotAllowed();
        if (_tokenOwner == address(0)) revert ZeroAddressNotAllowed();
        if (_tokenIdentity[_token] != address(0)) revert TokenAlreadyLinked();

        string memory salt = string.concat("Token", Strings.toHexString(_token));
        if (_saltTaken[salt]) revert SaltAlreadyTaken();

        address identity = _deployIdentity(salt, _tokenOwner);
        _saltTaken[salt] = true;
        _tokenIdentity[_token] = identity;

        emit TokenIdentityCreated(identity, _token);
        return identity;
    }

    function getTokenIdentity(address _token) external view returns (address) {
        return _tokenIdentity[_token];
    }

    function getAddress(string memory _salt, address _wallet) public view returns (address) {
        return Create2.computeAddress(
            bytes32(keccak256(abi.encodePacked(_salt))),
            keccak256(
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(_identityImplementation, abi.encodeCall(Identity.initialize, (_wallet)))
                )
            )
        );
    }

    function _deployIdentity(string memory _salt, address _wallet) private returns (address) {
        address addr = getAddress(_salt, _wallet);

        // If identity already exists, return it
        if (addr.code.length > 0) {
            return addr;
        }

        // Deploy new identity
        return address(
            new ERC1967Proxy{ salt: bytes32(keccak256(abi.encodePacked(_salt))) }(
                _identityImplementation, abi.encodeCall(Identity.initialize, (_wallet))
            )
        );
    }
}
