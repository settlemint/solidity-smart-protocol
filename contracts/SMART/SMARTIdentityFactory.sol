// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.27;

import { Identity } from "../onchainid/Identity.sol";
import { IIdentity } from "../onchainid/interface/IIdentity.sol";
import { IERC734 } from "../onchainid/interface/IERC734.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// --- Errors ---
error ZeroAddressNotAllowed();
error SaltAlreadyTaken();
error WalletAlreadyLinked();
error WalletInManagementKeys();
error TokenAlreadyLinked();

contract SMARTIdentityFactory is Ownable {
    // --- Storage Variables ---
    address private immutable _identityImplementation;

    mapping(string => bool) private _saltTaken;
    mapping(address => address) private _identities; // Changed bool to address
    mapping(address => address) private _tokenIdentities;

    // --- Events ---
    event IdentityCreated(address indexed identity, address indexed wallet);
    event TokenIdentityCreated(address indexed identity, address indexed token);

    // --- Constructor ---
    constructor() Ownable(_msgSender()) {
        _identityImplementation = address(new Identity(address(0), true));
    }

    // --- State-Changing Functions ---
    function createIdentity(address _wallet, bytes32[] memory _managementKeys) external onlyOwner returns (address) {
        if (_wallet == address(0)) revert ZeroAddressNotAllowed();
        if (_identities[_wallet] != address(0)) revert WalletAlreadyLinked(); // Comparison with address(0)

        address identity = _createIdentityInternal("OID", _wallet, _wallet);

        // Add management keys if provided
        if (_managementKeys.length > 0) {
            for (uint256 i = 0; i < _managementKeys.length; i++) {
                if (_managementKeys[i] == keccak256(abi.encode(_wallet))) {
                    revert WalletInManagementKeys();
                }
                IERC734(identity).addKey(_managementKeys[i], 1, 1);
            }
        }

        _identities[_wallet] = identity; // Assign identity address

        emit IdentityCreated(identity, _wallet);
        return identity;
    }

    function createTokenIdentity(address _token, address _tokenOwner) external onlyOwner returns (address) {
        if (_token == address(0)) revert ZeroAddressNotAllowed();
        if (_tokenOwner == address(0)) revert ZeroAddressNotAllowed();
        if (_tokenIdentities[_token] != address(0)) revert TokenAlreadyLinked();

        address identity = _createIdentityInternal("Token", _token, _tokenOwner);

        _tokenIdentities[_token] = identity;

        emit TokenIdentityCreated(identity, _token);
        return identity;
    }

    // --- View Functions ---
    function getTokenIdentity(address _token) external view returns (address) {
        return _tokenIdentities[_token];
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

    // --- Internal Functions ---

    /**
     * @dev Internal function to handle common identity creation logic.
     */
    function _createIdentityInternal(
        string memory _saltPrefix,
        address _entityAddress,
        address _ownerAddress
    )
        private
        returns (address)
    {
        string memory salt = string.concat(_saltPrefix, Strings.toHexString(_entityAddress));
        if (_saltTaken[salt]) revert SaltAlreadyTaken();

        address identity = _deployIdentity(salt, _ownerAddress);
        _saltTaken[salt] = true;
        return identity;
    }

    /**
     * @dev Deploys an ERC1967 proxy pointing to the identity implementation.
     * Uses Create2 for deterministic address calculation.
     * Returns the existing address if already deployed.
     */
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
