// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlEnumerableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Interface imports
import { IERC734 } from "@onchainid/contracts/interface/IERC734.sol";
import { IImplementationAuthority } from "@onchainid/contracts/interface/IImplementationAuthority.sol";
import { ISMARTIdentityFactory } from "./ISMARTIdentityFactory.sol";

// System imports
import { InvalidSystemAddress } from "../SMARTSystemErrors.sol";

// Implementation imports
import { SMARTIdentityProxy } from "./identities/SMARTIdentityProxy.sol";
import { SMARTTokenIdentityProxy } from "./identities/SMARTTokenIdentityProxy.sol";

// --- Errors ---
error ZeroAddressNotAllowed();
error SaltAlreadyTaken(string salt);
error WalletAlreadyLinked(address wallet);
error WalletInManagementKeys(); // Consider if still needed
error TokenAlreadyLinked(address token);
error InvalidAuthorityAddress();
error DeploymentAddressMismatch();

/// @title SMART Identity Factory
/// @notice Factory for creating deterministic OnchainID identities (using IdentityProxy)
///         for investor wallets and tokens.
/// @dev Deploys `IdentityProxy` contracts using CREATE2, pointing them to an `ImplementationAuthority`
///      which determines the logic contract address. Uses Ownable for access control.
contract SMARTIdentityFactoryImplementation is
    Initializable,
    ERC165Upgradeable,
    ERC2771ContextUpgradeable,
    AccessControlEnumerableUpgradeable,
    ISMARTIdentityFactory
{
    // --- Constants ---
    string public constant TOKEN_SALT_PREFIX = "Token";
    string public constant WALLET_SALT_PREFIX = "OID";

    // --- Roles ---
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    // --- Storage Variables ---
    /// @notice The address of the ISMARTSystem contract that provides the identity implementations.
    address private _system;

    /// @notice Mapping to track used salts (derived from entity address) to prevent duplicates.
    mapping(bytes32 => bool) private _saltTakenByteSalt;
    /// @notice Mapping from investor wallet address to its deployed IdentityProxy address.
    mapping(address => address) private _identities;
    /// @notice Mapping from token contract address to its deployed IdentityProxy address.
    mapping(address => address) private _tokenIdentities;

    // --- Events ---
    /// @notice Emitted when a new identity is created for an investor wallet.
    /// @param sender The address of the account that performed the creation.
    /// @param identity The address of the deployed IdentityProxy.
    /// @param wallet The investor wallet address.
    event IdentityCreated(address indexed sender, address indexed identity, address indexed wallet);
    /// @notice Emitted when a new identity is created for a token contract.
    /// @param sender The address of the account that performed the creation.
    /// @param identity The address of the deployed IdentityProxy.
    /// @param token The token contract address.
    event TokenIdentityCreated(address indexed sender, address indexed identity, address indexed token);

    // --- Constructor --- (Disable direct construction)
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) payable ERC2771ContextUpgradeable(trustedForwarder) {
        _disableInitializers();
    }

    // --- Initializer ---
    /// @notice Initializes the identity factory.
    /// @dev Sets the initial owner and the ImplementationAuthority address.
    /// @param systemAddress The address of the ISMARTSystem contract that provides the implementation.
    /// @param initialAdmin The address that will receive the ownership.
    function initialize(address systemAddress, address initialAdmin) public initializer {
        if (systemAddress == address(0)) revert InvalidSystemAddress();

        __ERC165_init_unchained();
        __AccessControlEnumerable_init_unchained();

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(REGISTRAR_ROLE, initialAdmin); // TODO: should he be the registrar?

        _system = systemAddress;
    }

    // --- State-Changing Functions (Owner Controlled) ---

    /// @notice Creates a deterministic IdentityProxy for an investor wallet.
    /// @dev Calculates salt, deploys proxy via CREATE2, sets initial management key to the wallet itself,
    ///      removes deployer key, adds specified management keys, and maps wallet to identity.
    ///      Only callable by the factory owner.
    /// @param _wallet The investor wallet address (will also be initial owner/manager).
    /// @param _managementKeys Optional array of additional management keys (keccak256 hashes) to add.
    /// @return The address of the newly created IdentityProxy.
    function createIdentity(
        address _wallet,
        bytes32[] calldata _managementKeys
    )
        external
        onlyRole(REGISTRAR_ROLE)
        returns (address)
    {
        if (_wallet == address(0)) revert ZeroAddressNotAllowed();
        if (_identities[_wallet] != address(0)) revert WalletAlreadyLinked(_wallet);

        // Deploy identity with _wallet as the initial management key passed to proxy constructor
        address identity = _createAndRegisterWalletIdentity(_wallet, _wallet);
        IERC734 identityContract = IERC734(identity);

        // Add specified management keys
        if (_managementKeys.length > 0) {
            uint256 managementKeysLength = _managementKeys.length;
            for (uint256 i = 0; i < managementKeysLength;) {
                if (_managementKeys[i] == keccak256(abi.encodePacked(_wallet))) revert WalletInManagementKeys();
                identityContract.addKey(_managementKeys[i], 1, 1); // Add key with purpose 1 (MANAGEMENT)
                unchecked {
                    ++i;
                }
            }
        }

        _identities[_wallet] = identity;
        emit IdentityCreated(_msgSender(), identity, _wallet);
        return identity;
    }

    /// @notice Creates a deterministic IdentityProxy for a token contract.
    /// @dev Calculates salt, deploys proxy via CREATE2, sets initial management key to the specified token owner,
    ///      and maps token address to identity.
    ///      Only callable by the factory owner.
    /// @param _token The token contract address.
    /// @param _tokenOwner The address designated as the owner/manager of the token\'s identity.
    /// @return The address of the newly created IdentityProxy.
    function createTokenIdentity(
        address _token,
        address _tokenOwner
    )
        external
        onlyRole(REGISTRAR_ROLE)
        returns (address)
    {
        if (_token == address(0)) revert ZeroAddressNotAllowed();
        if (_tokenOwner == address(0)) revert ZeroAddressNotAllowed();
        if (_tokenIdentities[_token] != address(0)) revert TokenAlreadyLinked(_token);

        // Deploy identity with _tokenOwner as the initial management key
        address identity = _createAndRegisterTokenIdentity(_token, _tokenOwner);

        _tokenIdentities[_token] = identity;
        emit TokenIdentityCreated(_msgSender(), identity, _token);
        return identity;
    }

    // --- View Functions ---

    /// @notice Retrieves the deployed IdentityProxy address for a given investor wallet.
    /// @param _wallet The investor wallet address.
    /// @return The address of the IdentityProxy, or address(0) if not created.
    function getIdentity(address _wallet) external view returns (address) {
        return _identities[_wallet];
    }

    /// @notice Retrieves the deployed IdentityProxy address for a given token contract.
    /// @param _token The token contract address.
    /// @return The address of the IdentityProxy, or address(0) if not created.
    function getTokenIdentity(address _token) external view returns (address) {
        return _tokenIdentities[_token];
    }

    /// @notice Computes the deterministic address where an IdentityProxy *will be* deployed for an investor wallet.
    /// @dev Calculates the salt internally using the WALLET_SALT_PREFIX and the wallet address.
    ///      Uses CREATE2 address calculation based on factory address, this internally generated salt,
    ///      and proxy bytecode + constructor args (which include the initial manager).
    /// @param _walletAddress The investor wallet address for which to calculate the identity address.
    /// @param _initialManager The address that will be the initial management key passed to the proxy constructor.
    /// @return The pre-computed deployment address.
    function calculateWalletIdentityAddress(
        address _walletAddress,
        address _initialManager
    )
        public
        view
        returns (address)
    {
        (bytes32 saltBytes,) = _calculateSalt(WALLET_SALT_PREFIX, _walletAddress);
        return _computeWalletProxyAddress(saltBytes, _initialManager);
    }

    /// @notice Computes the deterministic address where an IdentityProxy *will be* deployed for a token contract.
    /// @dev Calculates the salt internally using the TOKEN_SALT_PREFIX and the token address.
    ///      Uses CREATE2 address calculation based on factory address, this internally generated salt,
    ///      and proxy bytecode + constructor args (which include the initial manager).
    /// @param _tokenAddress The token contract address for which to calculate the identity address.
    /// @param _initialManager The address that will be the initial management key passed to the proxy constructor.
    /// @return The pre-computed deployment address.
    function calculateTokenIdentityAddress(
        address _tokenAddress,
        address _initialManager
    )
        public
        view
        returns (address)
    {
        (bytes32 saltBytes,) = _calculateSalt(TOKEN_SALT_PREFIX, _tokenAddress);
        return _computeTokenProxyAddress(saltBytes, _initialManager);
    }

    /// @notice Returns the address of the ISMARTSystem contract that provides the identity implementations.
    /// @return The address of the ISMARTSystem contract.
    function getSystem() external view returns (address) {
        return _system;
    }

    // --- Internal Functions ---

    /// @dev Internal function to compute salt, check availability, and deploy a wallet identity proxy.
    /// @param _walletAddress The address of the wallet being identified.
    /// @param _initialManagerAddress The address to set as the initial management key.
    /// @return The address of the deployed SMARTIdentityProxy.
    function _createAndRegisterWalletIdentity(
        address _walletAddress,
        address _initialManagerAddress
    )
        private
        returns (address)
    {
        (bytes32 saltBytes, string memory saltString) = _calculateSalt(WALLET_SALT_PREFIX, _walletAddress);

        if (_saltTakenByteSalt[saltBytes]) revert SaltAlreadyTaken(saltString);

        address identity = _deployWalletProxy(saltBytes, _initialManagerAddress);

        _saltTakenByteSalt[saltBytes] = true;
        return identity;
    }

    /// @dev Internal function to compute salt, check availability, and deploy a token identity proxy.
    /// @param _tokenAddress The address of the token being identified.
    /// @param _initialManagerAddress The address to set as the initial management key.
    /// @return The address of the deployed TokenIdentityProxy.
    function _createAndRegisterTokenIdentity(
        address _tokenAddress,
        address _initialManagerAddress
    )
        private
        returns (address)
    {
        (bytes32 saltBytes, string memory saltString) = _calculateSalt(TOKEN_SALT_PREFIX, _tokenAddress);

        if (_saltTakenByteSalt[saltBytes]) revert SaltAlreadyTaken(saltString);

        address identity = _deployTokenProxy(saltBytes, _initialManagerAddress);

        _saltTakenByteSalt[saltBytes] = true;
        return identity;
    }

    /// @dev Calculates the salt for a given prefix and address.
    /// @param _saltPrefix The prefix for the salt.
    /// @param _address The address to calculate the salt for.
    /// @return saltBytes The calculated salt.
    /// @return saltString The calculated salt as a string.
    function _calculateSalt(
        string memory _saltPrefix,
        address _address
    )
        internal
        pure
        returns (bytes32 saltBytes, string memory saltString)
    {
        saltString = string.concat(_saltPrefix, Strings.toHexString(_address));
        saltBytes = keccak256(abi.encodePacked(saltString));

        return (saltBytes, saltString);
    }

    /// @dev Computes the deterministic address for a SMARTIdentityProxy (for wallets).
    function _computeWalletProxyAddress(bytes32 _saltBytes, address _initialManager) internal view returns (address) {
        (bytes memory proxyBytecode, bytes memory constructorArgs) = _getWalletProxyAndConstructorArgs(_initialManager);
        return Create2.computeAddress(_saltBytes, keccak256(abi.encodePacked(proxyBytecode, constructorArgs)));
    }

    /// @dev Computes the deterministic address for a TokenIdentityProxy.
    function _computeTokenProxyAddress(bytes32 _saltBytes, address _initialManager) internal view returns (address) {
        (bytes memory proxyBytecode, bytes memory constructorArgs) = _getTokenProxyAndConstructorArgs(_initialManager);
        return Create2.computeAddress(_saltBytes, keccak256(abi.encodePacked(proxyBytecode, constructorArgs)));
    }

    /// @dev Deploys a SMARTIdentityProxy (for wallets) using Create2.
    function _deployWalletProxy(bytes32 _saltBytes, address _initialManager) private returns (address) {
        address predictedAddr = _computeWalletProxyAddress(_saltBytes, _initialManager);

        (bytes memory proxyBytecode, bytes memory constructorArgs) = _getWalletProxyAndConstructorArgs(_initialManager);

        return _deployProxy(predictedAddr, proxyBytecode, constructorArgs, _saltBytes);
    }

    /// @dev Deploys a TokenIdentityProxy using Create2.
    function _deployTokenProxy(bytes32 _saltBytes, address _initialManager) private returns (address) {
        address predictedAddr = _computeTokenProxyAddress(_saltBytes, _initialManager);

        (bytes memory proxyBytecode, bytes memory constructorArgs) = _getTokenProxyAndConstructorArgs(_initialManager);

        return _deployProxy(predictedAddr, proxyBytecode, constructorArgs, _saltBytes);
    }

    function _getWalletProxyAndConstructorArgs(address _initialManager)
        private
        view
        returns (bytes memory, bytes memory)
    {
        bytes memory proxyBytecode = type(SMARTIdentityProxy).creationCode;
        bytes memory constructorArgs = abi.encode(_system, _initialManager);
        return (proxyBytecode, constructorArgs);
    }

    function _getTokenProxyAndConstructorArgs(address _initialManager)
        private
        view
        returns (bytes memory, bytes memory)
    {
        bytes memory proxyBytecode = type(SMARTTokenIdentityProxy).creationCode;
        bytes memory constructorArgs = abi.encode(_system, _initialManager);
        return (proxyBytecode, constructorArgs);
    }

    /// @dev Deploys a proxy using Create2.
    function _deployProxy(
        address _predictedAddr,
        bytes memory _proxyBytecode,
        bytes memory _constructorArgs,
        bytes32 _saltBytes
    )
        private
        returns (address)
    {
        bytes memory deploymentBytecode = abi.encodePacked(_proxyBytecode, _constructorArgs);

        address deployedAddress = Create2.deploy(0, _saltBytes, deploymentBytecode);

        if (deployedAddress != _predictedAddr) revert DeploymentAddressMismatch();
        return deployedAddress;
    }

    // --- Context Overrides (ERC2771) ---

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

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable, ERC165Upgradeable)
        returns (bool)
    {
        return interfaceId == type(ISMARTIdentityFactory).interfaceId || super.supportsInterface(interfaceId);
    }
}
