// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

// Interface imports
import { IERC734 } from "../onchainid/interface/IERC734.sol";
import { IImplementationAuthority } from "../onchainid/interface/IImplementationAuthority.sol";

// Implementation imports
import { IdentityProxy } from "../onchainid/proxy/IdentityProxy.sol";

// --- Errors ---
error ZeroAddressNotAllowed();
error SaltAlreadyTaken(string salt);
error WalletAlreadyLinked(address wallet);
error WalletInManagementKeys(); // Consider if still needed
error TokenAlreadyLinked(address token);
error InvalidAuthorityAddress();

/// @title SMART Identity Factory
/// @notice Factory for creating deterministic OnchainID identities (using IdentityProxy)
///         for investor wallets and tokens.
/// @dev Deploys `IdentityProxy` contracts using CREATE2, pointing them to an `ImplementationAuthority`
///      which determines the logic contract address. Uses Ownable for access control.
contract SMARTIdentityFactory is Initializable, ERC2771ContextUpgradeable, OwnableUpgradeable {
    // --- Storage Variables ---
    /// @notice The address of the ImplementationAuthority contract that dictates the logic for created identities.
    address private _implementationAuthority;

    /// @notice Mapping to track used salts (derived from entity address) to prevent duplicates.
    mapping(string => bool) private _saltTaken;
    /// @notice Mapping from investor wallet address to its deployed IdentityProxy address.
    mapping(address => address) private _identities;
    /// @notice Mapping from token contract address to its deployed IdentityProxy address.
    mapping(address => address) private _tokenIdentities;

    // --- Events ---
    /// @notice Emitted when a new identity is created for an investor wallet.
    /// @param identity The address of the deployed IdentityProxy.
    /// @param wallet The investor wallet address.
    event IdentityCreated(address indexed identity, address indexed wallet);
    /// @notice Emitted when a new identity is created for a token contract.
    /// @param identity The address of the deployed IdentityProxy.
    /// @param token The token contract address.
    event TokenIdentityCreated(address indexed identity, address indexed token);
    /// @notice Emitted when the ImplementationAuthority address is set or updated.
    event ImplementationAuthoritySet(address indexed newAuthority);

    // --- Constructor --- (Disable direct construction)
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC2771ContextUpgradeable(address(0)) {
        _disableInitializers();
    }

    // --- Initializer ---
    /// @notice Initializes the identity factory.
    /// @dev Sets the initial owner and the ImplementationAuthority address.
    /// @param initialOwner The address that will receive the ownership.
    /// @param implementationAuthority_ The address of the `IImplementationAuthority` contract.
    function initialize(address initialOwner, address implementationAuthority_) public initializer {
        if (implementationAuthority_ == address(0)) revert InvalidAuthorityAddress();
        __Ownable_init(initialOwner);
        // ERC2771Context is initialized by the constructor
        _implementationAuthority = implementationAuthority_;
        emit ImplementationAuthoritySet(implementationAuthority_);
    }

    // --- State-Changing Functions (Owner Controlled) ---

    /**
     * @notice Creates a deterministic IdentityProxy for an investor wallet.
     * @dev Calculates salt, deploys proxy via CREATE2, sets initial management key to the wallet itself,
     *      removes deployer key, adds specified management keys, and maps wallet to identity.
     *      Only callable by the factory owner.
     * @param _wallet The investor wallet address (will also be initial owner/manager).
     * @param _managementKeys Optional array of additional management keys (keccak256 hashes) to add.
     * @return The address of the newly created IdentityProxy.
     */
    function createIdentity(address _wallet, bytes32[] memory _managementKeys) external onlyOwner returns (address) {
        if (_wallet == address(0)) revert ZeroAddressNotAllowed();
        if (_identities[_wallet] != address(0)) revert WalletAlreadyLinked(_wallet);

        // Deploy identity with _wallet as the initial management key passed to proxy constructor
        address identity = _createIdentityInternal("OID", _wallet, _wallet);
        IERC734 identityContract = IERC734(identity);

        // Add specified management keys
        if (_managementKeys.length > 0) {
            for (uint256 i = 0; i < _managementKeys.length; i++) {
                if (_managementKeys[i] == keccak256(abi.encodePacked(_wallet))) revert WalletInManagementKeys();
                identityContract.addKey(_managementKeys[i], 1, 1); // Add key with purpose 1 (MANAGEMENT)
            }
        }

        _identities[_wallet] = identity;
        emit IdentityCreated(identity, _wallet);
        return identity;
    }

    /**
     * @notice Creates a deterministic IdentityProxy for a token contract.
     * @dev Calculates salt, deploys proxy via CREATE2, sets initial management key to the specified token owner,
     *      and maps token address to identity.
     *      Only callable by the factory owner.
     * @param _token The token contract address.
     * @param _tokenOwner The address designated as the owner/manager of the token's identity.
     * @return The address of the newly created IdentityProxy.
     */
    function createTokenIdentity(address _token, address _tokenOwner) external onlyOwner returns (address) {
        if (_token == address(0)) revert ZeroAddressNotAllowed();
        if (_tokenOwner == address(0)) revert ZeroAddressNotAllowed();
        if (_tokenIdentities[_token] != address(0)) revert TokenAlreadyLinked(_token);

        // Deploy identity with _tokenOwner as the initial management key
        address identity = _createIdentityInternal("Token", _token, _tokenOwner);

        _tokenIdentities[_token] = identity;
        emit TokenIdentityCreated(identity, _token);
        return identity;
    }

    // --- View Functions ---

    /**
     * @notice Retrieves the deployed IdentityProxy address for a given investor wallet.
     * @param _wallet The investor wallet address.
     * @return The address of the IdentityProxy, or address(0) if not created.
     */
    function getIdentity(address _wallet) external view returns (address) {
        return _identities[_wallet];
    }

    /**
     * @notice Retrieves the deployed IdentityProxy address for a given token contract.
     * @param _token The token contract address.
     * @return The address of the IdentityProxy, or address(0) if not created.
     */
    function getTokenIdentity(address _token) external view returns (address) {
        return _tokenIdentities[_token];
    }

    /**
     * @notice Computes the deterministic address where an IdentityProxy *will be* deployed for a given salt string and
     * initial manager.
     * @dev Uses CREATE2 address calculation based on factory address, salt, and proxy bytecode + constructor args.
     * @param _saltString The unique salt string (e.g., "OID" + wallet address as hex).
     * @param _initialManager The address that will be the initial management key passed to the proxy constructor.
     * @return The pre-computed deployment address.
     */
    function getAddressForSaltString(
        string memory _saltString,
        address _initialManager
    )
        public
        view
        returns (address)
    {
        bytes32 saltBytes = keccak256(abi.encodePacked(_saltString));
        return getAddressForByteSalt(saltBytes, _initialManager);
    }

    /**
     * @notice Computes the deterministic address where an IdentityProxy *will be* deployed for a given salt hash and
     * initial manager.
     * @dev Internal logic used by `getAddressForSaltString` and deployment.
     * @param _saltBytes The keccak256 hash of the unique salt string.
     * @param _initialManager The address that will be the initial management key passed to the proxy constructor.
     * @return The pre-computed deployment address.
     */
    function getAddressForByteSalt(bytes32 _saltBytes, address _initialManager) public view returns (address) {
        bytes memory proxyBytecode = type(IdentityProxy).creationCode;
        // Constructor arguments for IdentityProxy: address implementationAuthority, address initialManagementKey
        bytes memory constructorArgs = abi.encode(_implementationAuthority, _initialManager);
        return Create2.computeAddress(_saltBytes, keccak256(abi.encodePacked(proxyBytecode, constructorArgs)));
    }

    /**
     * @notice Returns the address of the ImplementationAuthority contract managing the identities created by this
     * factory.
     * @return The address of the IImplementationAuthority contract.
     */
    function getImplementationAuthority() external view returns (address) {
        return _implementationAuthority;
    }

    // --- Internal Functions ---

    /**
     * @dev Internal function to compute salt, check availability, and deploy the identity proxy.
     * @param _saltPrefix Prefix for the salt ("OID" or "Token").
     * @param _entityAddress The address of the wallet or token being identified.
     * @param _initialManagerAddress The address to set as the initial management key in the IdentityProxy constructor.
     * @return The address of the deployed IdentityProxy.
     */
    function _createIdentityInternal(
        string memory _saltPrefix,
        address _entityAddress,
        address _initialManagerAddress
    )
        private
        returns (address)
    {
        string memory saltString = string.concat(_saltPrefix, Strings.toHexString(_entityAddress));
        if (_saltTaken[saltString]) revert SaltAlreadyTaken(saltString);

        bytes32 saltBytes = keccak256(abi.encodePacked(saltString));
        address identity = _deployIdentity(saltBytes, _initialManagerAddress);

        _saltTaken[saltString] = true;
        return identity;
    }

    /**
     * @dev Deploys an IdentityProxy using Create2.
     * @param _saltBytes The keccak256 hash of the unique salt string.
     * @param _initialManager The address to be passed as initialManagementKey to the IdentityProxy constructor.
     * @return The address of the deployed IdentityProxy.
     */
    function _deployIdentity(bytes32 _saltBytes, address _initialManager) private returns (address) {
        address predictedAddr = getAddressForByteSalt(_saltBytes, _initialManager);

        bytes memory proxyBytecode = type(IdentityProxy).creationCode;
        bytes memory constructorArgs = abi.encode(_implementationAuthority, _initialManager);
        bytes memory deploymentBytecode = abi.encodePacked(proxyBytecode, constructorArgs);

        address deployedAddress = Create2.deploy(0, _saltBytes, deploymentBytecode);

        require(deployedAddress == predictedAddr, "SMARTIdentityFactory: Deployment address mismatch");
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
}
