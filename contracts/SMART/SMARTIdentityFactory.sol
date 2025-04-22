// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.27;

import { Identity } from "../onchainid/Identity.sol";
import { IIdentity } from "../onchainid/interface/IIdentity.sol";
import { IERC734 } from "../onchainid/interface/IERC734.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

// --- Errors ---
error ZeroAddressNotAllowed();
error SaltAlreadyTaken();
error WalletAlreadyLinked();
error WalletInManagementKeys();
error TokenAlreadyLinked();
error InvalidImplementationAddress();

/// @title SMARTIdentityFactory
/// @notice Factory for creating deterministic OnchainID identities for wallets and tokens.
contract SMARTIdentityFactory is Initializable, ERC2771ContextUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    // --- Storage Variables ---
    address private _identityImplementation;

    mapping(string => bool) private _saltTaken;
    mapping(address => address) private _identities;
    mapping(address => address) private _tokenIdentities;

    // --- Events ---
    event IdentityCreated(address indexed identity, address indexed wallet);
    event TokenIdentityCreated(address indexed identity, address indexed token);
    event IdentityImplementationSet(address indexed newImplementation);

    // --- Constructor ---
    constructor() ERC2771ContextUpgradeable(address(0)) {
        _disableInitializers();
    }

    // --- Initializer ---
    function initialize(address initialOwner, address identityImplementation_) public initializer {
        if (identityImplementation_ == address(0)) revert InvalidImplementationAddress();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        _identityImplementation = identityImplementation_;
        emit IdentityImplementationSet(identityImplementation_);
    }

    // --- State-Changing Functions ---
    function createIdentity(address _wallet, bytes32[] memory _managementKeys) external onlyOwner returns (address) {
        if (_wallet == address(0)) revert ZeroAddressNotAllowed();
        if (_identities[_wallet] != address(0)) revert WalletAlreadyLinked();

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

        _identities[_wallet] = identity;

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

    function setIdentityImplementation(address newImplementation_) external onlyOwner {
        if (newImplementation_ == address(0)) revert InvalidImplementationAddress();
        _identityImplementation = newImplementation_;
        emit IdentityImplementationSet(newImplementation_);
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

    function getIdentityImplementation() external view returns (address) {
        return _identityImplementation;
    }

    // --- Internal Functions ---
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

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }

    // --- Upgradeability ---
    function _authorizeUpgrade(address newImplementation) internal override(UUPSUpgradeable) onlyOwner { }
}
