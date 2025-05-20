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
import { ISMARTIdentityFactory } from "./ISMARTIdentityFactory.sol";
import { ISMARTIdentity } from "./identities/ISMARTIdentity.sol";
import { ISMARTTokenIdentity } from "./identities/ISMARTTokenIdentity.sol";

// System imports
import { InvalidSystemAddress } from "../SMARTSystemErrors.sol"; // Assuming this is correctly placed
import { ISMARTSystem } from "../ISMARTSystem.sol";

// Implementation imports
import { SMARTIdentityProxy } from "./identities/SMARTIdentityProxy.sol";
import { SMARTTokenIdentityProxy } from "./identities/SMARTTokenIdentityProxy.sol";

// Constants
import { SMARTRoles } from "../../SMARTRoles.sol";

// --- Errors ---
/// @notice Indicates that an operation was attempted with the zero address (address(0))
///         where a valid, non-zero address was expected (e.g., for a wallet or token owner).
error ZeroAddressNotAllowed();
/// @notice Indicates that a deterministic deployment (CREATE2) was attempted with a salt that has already been used.
/// @param salt The string representation of the salt that was already taken.
/// @dev Salts must be unique for each CREATE2 deployment from the same factory to ensure unique addresses.
error SaltAlreadyTaken(string salt);
/// @notice Indicates an attempt to create an identity for a wallet that already has one linked in this factory.
/// @param wallet The address of the wallet that is already linked to an identity.
error WalletAlreadyLinked(address wallet);
/// @notice Indicates that a wallet address was found within the list of management keys being added to its own
/// identity.
/// @dev An identity's own wallet address (if it represents a user) typically has management capabilities by default or
/// through specific key types;
/// explicitly adding it as a generic management key might be redundant or an error.
error WalletInManagementKeys();
/// @notice Indicates an attempt to create an identity for a token that already has one linked in this factory.
/// @param token The address of the token contract that is already linked to an identity.
error TokenAlreadyLinked(address token);
/// @notice Indicates that the address deployed via CREATE2 does not match the pre-calculated predicted address.
/// @dev This is a critical error suggesting a potential issue in the CREATE2 computation, salt, or deployment bytecode,
/// or an unexpected change in blockchain state between prediction and deployment.
error DeploymentAddressMismatch();
/// @notice Indicates that the identity implementation is invalid.
error InvalidIdentityImplementation();
/// @notice Indicates that the token identity implementation is invalid.
error InvalidTokenIdentityImplementation();

/// @title SMART Identity Factory Implementation
/// @author SettleMint Tokenization Services
/// @notice This contract is the upgradeable logic implementation for creating and managing on-chain identities
///         for both user wallets and token contracts within the SMART Protocol.
/// @dev It leverages OpenZeppelin's `Create2` library to deploy identity proxy contracts (`SMARTIdentityProxy` for
/// wallets,
///      `SMARTTokenIdentityProxy` for tokens) at deterministic addresses. These proxies point to logic implementations
///      whose addresses are provided by the central `ISMARTSystem` contract, enabling upgradeability of the identity
/// logic.
///      The factory uses `AccessControlEnumerableUpgradeable` for role-based access control, notably the
/// `REGISTRAR_ROLE`
///      for creating identities. It is also `ERC2771ContextUpgradeable` for meta-transaction support.
///      The identities created are based on the ERC725 (OnchainID) standard, managed via ERC734 for key management.
contract SMARTIdentityFactoryImplementation is
    Initializable,
    ERC165Upgradeable,
    ERC2771ContextUpgradeable,
    AccessControlEnumerableUpgradeable,
    ISMARTIdentityFactory
{
    // --- Constants ---
    /// @notice Prefix used in salt calculation for creating token identities to ensure unique salt generation.
    /// @dev For example, salt might be `keccak256(abi.encodePacked("Token", <tokenAddressHex>))`.
    string public constant TOKEN_SALT_PREFIX = "Token";
    /// @notice Prefix used in salt calculation for creating wallet identities to ensure unique salt generation.
    /// @dev For example, salt might be `keccak256(abi.encodePacked("OID", <walletAddressHex>))` (OID stands for
    /// OnchainID).
    string public constant WALLET_SALT_PREFIX = "OID";

    // --- Storage Variables ---
    /// @notice The address of the `ISMARTSystem` contract.
    /// @dev This system contract provides the addresses of the current logic implementations for `SMARTIdentity`
    ///      and `SMARTTokenIdentity` contracts that the deployed proxies will point to.
    address private _system;

    /// @notice Mapping to track whether a specific salt (represented as `bytes32`) has already been used for a CREATE2
    /// deployment by this factory.
    /// @dev This prevents deploying multiple contracts at the same deterministic address, which would fail or
    /// overwrite.
    /// `bytes32` is used as the key for gas efficiency compared to `string`.
    mapping(bytes32 byteSalt => bool isTaken) private _saltTakenByteSalt;
    /// @notice Mapping from an investor's wallet address to the address of its deployed `SMARTIdentityProxy` contract.
    /// @dev This allows for quick lookup of an existing identity for a given wallet.
    mapping(address wallet => address identityProxy) private _identities;
    /// @notice Mapping from a token contract's address to the address of its deployed `SMARTTokenIdentityProxy`
    /// contract.
    /// @dev This allows for quick lookup of an existing identity for a given token.
    mapping(address token => address identityProxy) private _tokenIdentities;

    // --- Events ---
    /// @notice Emitted when a new identity contract is successfully created and registered for an investor wallet.
    /// @param sender The address that initiated the identity creation (e.g., an address with `REGISTRAR_ROLE`).
    /// @param identity The address of the newly deployed `SMARTIdentityProxy` contract.
    /// @param wallet The investor wallet address for which the identity was created.
    event IdentityCreated(address indexed sender, address indexed identity, address indexed wallet);
    /// @notice Emitted when a new identity contract is successfully created and registered for a token contract.
    /// @param sender The address that initiated the token identity creation (e.g., an address with `REGISTRAR_ROLE`).
    /// @param identity The address of the newly deployed `SMARTTokenIdentityProxy` contract.
    /// @param token The address of the token contract for which the identity was created.
    event TokenIdentityCreated(address indexed sender, address indexed identity, address indexed token);
    /// @notice Emitted when the TOKEN_REGISTRAR_ROLE is granted to an account.
    /// @param account The account that was granted the role.
    /// @param sender The account that granted the role.
    event TokenRegistrarRoleGranted(address indexed account, address indexed sender);
    /// @notice Emitted when the TOKEN_REGISTRAR_ROLE is revoked from an account.
    /// @param account The account that had the role revoked.
    /// @param sender The account that revoked the role.
    event TokenRegistrarRoleRevoked(address indexed account, address indexed sender);

    // --- Constructor ---
    /// @notice Constructor for the identity factory implementation.
    /// @dev This is part of OpenZeppelin's upgradeable contracts pattern.
    /// It initializes `ERC2771ContextUpgradeable` with the `trustedForwarder` address for meta-transactions.
    /// `_disableInitializers()` prevents the `initialize` function from being called on the implementation contract
    /// directly,
    /// reserving it for the proxy context during deployment or upgrade.
    /// @param trustedForwarder The address of the ERC-2771 trusted forwarder for gasless transactions.
    /// @custom:oz-upgrades-unsafe-allow constructor Required by OpenZeppelin Upgrades plugins for upgradeable
    /// contracts.
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
        _disableInitializers();
    }

    // --- Initializer ---
    /// @notice Initializes the `SMARTIdentityFactoryImplementation` contract, typically called once by the proxy after
    /// deployment.
    /// @dev Sets up essential state for the factory:
    /// 1. Validates that `systemAddress` is not the zero address.
    /// 2. Initializes ERC165 for interface detection.
    /// 3. Initializes AccessControl, granting `DEFAULT_ADMIN_ROLE` and `REGISTRAR_ROLE` to `initialAdmin`.
    ///    The `DEFAULT_ADMIN_ROLE` can manage other roles, while `REGISTRAR_ROLE` allows identity creation.
    /// 4. Stores the `systemAddress` which provides identity logic implementations.
    /// @param systemAddress The address of the central `ISMARTSystem` contract. This contract is crucial as it dictates
    ///                      which identity logic implementation contracts the new identity proxies will point to.
    /// @param initialAdmin The address that will be granted initial administrative and registrar privileges over this
    /// factory.
    /// @dev The `initializer` modifier ensures this function can only be called once.
    function initialize(address systemAddress, address initialAdmin) public virtual initializer {
        if (systemAddress == address(0)) revert InvalidSystemAddress();

        __ERC165_init_unchained();
        __AccessControlEnumerable_init_unchained();

        if (
            !IERC165(ISMARTSystem(systemAddress).identityImplementation()).supportsInterface(
                type(ISMARTIdentity).interfaceId
            )
        ) {
            revert InvalidIdentityImplementation();
        }

        if (
            !IERC165(ISMARTSystem(systemAddress).tokenIdentityImplementation()).supportsInterface(
                type(ISMARTTokenIdentity).interfaceId
            )
        ) {
            revert InvalidTokenIdentityImplementation();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(SMARTRoles.REGISTRAR_ROLE, initialAdmin);
        _grantRole(SMARTRoles.TOKEN_REGISTRAR_MANAGER_ROLE, initialAdmin);
        _grantRole(SMARTRoles.TOKEN_REGISTRAR_MANAGER_ROLE, systemAddress);
        _setRoleAdmin(SMARTRoles.TOKEN_REGISTRAR_ROLE, SMARTRoles.TOKEN_REGISTRAR_MANAGER_ROLE);

        _system = systemAddress;
    }

    // --- State-Changing Functions (Owner Controlled) ---

    /// @inheritdoc ISMARTIdentityFactory
    /// @notice Creates a deterministic on-chain identity (a `SMARTIdentityProxy`) for a given investor wallet address.
    /// @dev This function can only be called by an address with the `REGISTRAR_ROLE`.
    /// It performs several steps:
    /// 1. Validates that `_wallet` is not the zero address and that an identity doesn't already exist for this wallet.
    /// 2. Calls `_createAndRegisterWalletIdentity` to handle the deterministic deployment of the `SMARTIdentityProxy`.
    ///    The `_wallet` itself is passed as the `_initialManager` to the proxy constructor.
    /// 3. Interacts with the newly deployed identity contract (as `IERC734`) to add any additional `_managementKeys`
    /// provided.
    ///    It ensures a management key is not the wallet itself (which is already a manager).
    /// 4. Stores the mapping from the `_wallet` address to the new `identity` contract address.
    /// 5. Emits an `IdentityCreated` event.
    /// @param _wallet The investor wallet address for which the identity is being created. This address will also be
    /// set as an initial manager of the identity.
    /// @param _managementKeys An array of `bytes32` values representing additional management keys (keccak256 hashes of
    /// public keys or addresses) to be added to the identity.
    ///                        These keys are granted `MANAGEMENT_KEY` purpose (purpose 1) according to ERC734.
    /// @return address The address of the newly created and registered `SMARTIdentityProxy` contract.
    function createIdentity(
        address _wallet,
        bytes32[] calldata _managementKeys
    )
        external
        virtual
        override
        onlyRole(SMARTRoles.REGISTRAR_ROLE)
        returns (
            address // Solidity style guide prefers no name for return in implementation if clear from Natspec
        )
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
                // Prevent adding the wallet's own key again if it was passed in _managementKeys
                if (_managementKeys[i] == keccak256(abi.encodePacked(_wallet))) revert WalletInManagementKeys();
                identityContract.addKey(_managementKeys[i], 1, 1); // Add key with ERC734 purpose 1 (MANAGEMENT_KEY) and
                    // type 1 (ECDSA key/address).
                unchecked {
                    ++i;
                }
            }
        }

        _identities[_wallet] = identity;
        emit IdentityCreated(_msgSender(), identity, _wallet);
        return identity;
    }

    /// @inheritdoc ISMARTIdentityFactory
    /// @notice Creates a deterministic on-chain identity (a `SMARTTokenIdentityProxy`) for a given token contract.
    /// @dev This function can only be called by an address with the `REGISTRAR_ROLE`.
    /// It performs several steps:
    /// 1. Validates that `_token` and `_tokenOwner` are not zero addresses and that an identity doesn't already exist
    /// for this token.
    /// 2. Calls `_createAndRegisterTokenIdentity` to handle the deterministic deployment of the
    /// `SMARTTokenIdentityProxy`.
    ///    The `_tokenOwner` is passed as the `_initialManager` to the proxy constructor.
    /// 3. Stores the mapping from the `_token` address to the new `identity` contract address.
    /// 4. Emits a `TokenIdentityCreated` event.
    /// @param _token The address of the token contract for which the identity is being created.
    /// @param _accessManager The address of the access manager contract that will be set as the initial owner/manager
    /// of the token's identity.
    /// @return address The address of the newly created and registered `SMARTTokenIdentityProxy` contract.
    function createTokenIdentity(
        address _token,
        address _accessManager
    )
        external
        virtual
        override
        onlyRole(SMARTRoles.TOKEN_REGISTRAR_ROLE)
        returns (address)
    {
        if (_token == address(0)) revert ZeroAddressNotAllowed();
        if (_accessManager == address(0)) revert ZeroAddressNotAllowed();
        if (_tokenIdentities[_token] != address(0)) revert TokenAlreadyLinked(_token);

        // Deploy identity with _tokenOwner as the initial management key
        address identity = _createAndRegisterTokenIdentity(_token, _accessManager);

        _tokenIdentities[_token] = identity;
        emit TokenIdentityCreated(_msgSender(), identity, _token);
        return identity;
    }

    // --- View Functions ---

    /// @inheritdoc ISMARTIdentityFactory
    /// @notice Retrieves the deployed `SMARTIdentityProxy` address associated with a given investor wallet.
    /// @param _wallet The investor wallet address to query.
    /// @return address The address of the `SMARTIdentityProxy` if one has been created for the `_wallet`, otherwise
    /// `address(0)`.
    function getIdentity(address _wallet) external view virtual override returns (address) {
        return _identities[_wallet];
    }

    /// @inheritdoc ISMARTIdentityFactory
    /// @notice Retrieves the deployed `SMARTTokenIdentityProxy` address associated with a given token contract.
    /// @param _token The token contract address to query.
    /// @return address The address of the `SMARTTokenIdentityProxy` if one has been created for the `_token`, otherwise
    /// `address(0)`.
    function getTokenIdentity(address _token) external view virtual override returns (address) {
        return _tokenIdentities[_token];
    }

    /// @inheritdoc ISMARTIdentityFactory
    /// @notice Computes the deterministic address at which a `SMARTIdentityProxy` for an investor wallet will be
    /// deployed (or was deployed).
    /// @dev This function uses the `CREATE2` address calculation logic. It first calculates a unique salt using
    ///      the `WALLET_SALT_PREFIX` and the `_walletAddress`. Then, it calls `_computeWalletProxyAddress` with this
    /// salt
    ///      and the `_initialManager` (which is part of the proxy's constructor arguments, affecting its creation code
    /// hash).
    ///      This allows prediction of the identity address before actual deployment.
    /// @param _walletAddress The investor wallet address for which to calculate the potential identity contract
    /// address.
    /// @param _initialManager The address that would be (or was) set as the initial management key for the identity's
    /// proxy constructor.
    /// @return address The pre-computed CREATE2 deployment address for the wallet's identity contract.
    function calculateWalletIdentityAddress(
        address _walletAddress,
        address _initialManager
    )
        public
        view
        virtual
        override
        returns (address)
    {
        (bytes32 saltBytes,) = _calculateSalt(WALLET_SALT_PREFIX, _walletAddress);
        return _computeWalletProxyAddress(saltBytes, _initialManager);
    }

    /// @inheritdoc ISMARTIdentityFactory
    /// @notice Computes the deterministic address at which a `SMARTTokenIdentityProxy` for a token contract will be
    /// deployed (or was deployed).
    /// @dev Similar to `calculateWalletIdentityAddress`, but for token identities. It uses the `TOKEN_SALT_PREFIX`.
    ///      It calls `_computeTokenProxyAddress` with the calculated salt and `_initialManager`.
    /// @param _tokenAddress The token contract address for which to calculate the potential identity contract address.
    /// @param _initialManager The address that would be (or was) set as the initial management key for the token
    /// identity's proxy constructor.
    /// @return address The pre-computed CREATE2 deployment address for the token's identity contract.
    function calculateTokenIdentityAddress(
        address _tokenAddress,
        address _initialManager
    )
        public
        view
        virtual
        override
        returns (address)
    {
        (bytes32 saltBytes,) = _calculateSalt(TOKEN_SALT_PREFIX, _tokenAddress);
        return _computeTokenProxyAddress(saltBytes, _initialManager);
    }

    /// @notice Returns the address of the `ISMARTSystem` contract that this factory uses.
    /// @dev The `ISMARTSystem` contract provides the addresses for the actual logic implementations
    ///      of `SMARTIdentity` and `SMARTTokenIdentity` that the deployed proxies will delegate to.
    /// @return address The address of the configured `ISMARTSystem` contract.
    function getSystem() external view returns (address) {
        return _system;
    }

    // --- Internal Functions ---

    /// @notice Internal function to handle the creation and registration of a wallet identity.
    /// @dev Calculates a unique salt for the `_walletAddress`, checks if the salt has been taken, deploys
    ///      the `SMARTIdentityProxy` using `_deployWalletProxy`, and marks the salt as taken.
    /// @param _walletAddress The address of the wallet for which to create an identity.
    /// @param _initialManagerAddress The address to be set as the initial management key in the proxy's constructor.
    /// @return address The address of the newly deployed `SMARTIdentityProxy`.
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

    /// @notice Internal function to handle the creation and registration of a token identity.
    /// @dev Calculates a unique salt for the `_tokenAddress`, checks if the salt has been taken, deploys
    ///      the `SMARTTokenIdentityProxy` using `_deployTokenProxy`, and marks the salt as taken.
    /// @param _tokenAddress The address of the token for which to create an identity.
    /// @param _accessManager The address of the access manager contract that will be set as the initial owner/manager
    /// @return address The address of the newly deployed `SMARTTokenIdentityProxy`.
    function _createAndRegisterTokenIdentity(address _tokenAddress, address _accessManager) private returns (address) {
        (bytes32 saltBytes, string memory saltString) = _calculateSalt(TOKEN_SALT_PREFIX, _tokenAddress);

        if (_saltTakenByteSalt[saltBytes]) revert SaltAlreadyTaken(saltString);

        address identity = _deployTokenProxy(saltBytes, _accessManager);

        _saltTakenByteSalt[saltBytes] = true;
        return identity;
    }

    /// @notice Calculates a deterministic salt for CREATE2 deployment based on a prefix and an address.
    /// @dev Concatenates the `_saltPrefix` (e.g., "OID" or "Token") with the hexadecimal string representation
    ///      of the `_address`. The result is then keccak256 hashed to produce the `bytes32` salt.
    ///      This ensures that for the same prefix and address, the salt is always the same.
    /// @param _saltPrefix A string prefix to ensure salt uniqueness across different types of identities (e.g., "OID"
    /// for wallets, "Token" for tokens).
    /// @param _address The address (wallet or token) to incorporate into the salt.
    /// @return saltBytes The calculated `bytes32` salt value.
    /// @return saltString The string representation of the salt before hashing (prefix + hexAddress), useful for error
    /// messages.
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
        // No explicit return needed due to named return variables
    }

    /// @notice Internal view function to compute the CREATE2 address for a `SMARTIdentityProxy` (for wallets).
    /// @dev It retrieves the proxy's creation bytecode and constructor arguments (which include the `_initialManager`
    /// and `_system` address)
    ///      and then uses `Create2.computeAddress` with the provided `_saltBytes`.
    /// @param _saltBytes The pre-calculated `bytes32` salt for the deployment.
    /// @param _initialManager The address that will be passed as the initial manager to the proxy's constructor.
    /// @return address The deterministically computed address where the proxy will be deployed.
    function _computeWalletProxyAddress(bytes32 _saltBytes, address _initialManager) internal view returns (address) {
        (bytes memory proxyBytecode, bytes memory constructorArgs) = _getWalletProxyAndConstructorArgs(_initialManager);
        // slither-disable-next-line encode-packed-collision: Standard pattern for Create2.computeAddress with
        // constructor args.
        return Create2.computeAddress(_saltBytes, keccak256(abi.encodePacked(proxyBytecode, constructorArgs)));
    }

    /// @notice Internal view function to compute the CREATE2 address for a `SMARTTokenIdentityProxy`.
    /// @dev Similar to `_computeWalletProxyAddress` but for token identities, using `_getTokenProxyAndConstructorArgs`.
    /// @param _saltBytes The pre-calculated `bytes32` salt for the deployment.
    /// @param _initialManager The address that will be passed as the initial manager to the proxy's constructor.
    /// @return address The deterministically computed address where the proxy will be deployed.
    function _computeTokenProxyAddress(bytes32 _saltBytes, address _initialManager) internal view returns (address) {
        (bytes memory proxyBytecode, bytes memory constructorArgs) = _getTokenProxyAndConstructorArgs(_initialManager);
        // slither-disable-next-line encode-packed-collision: Standard pattern for Create2.computeAddress with
        // constructor args.
        return Create2.computeAddress(_saltBytes, keccak256(abi.encodePacked(proxyBytecode, constructorArgs)));
    }

    /// @notice Internal function to deploy a `SMARTIdentityProxy` (for wallets) using CREATE2.
    /// @dev It first computes the predicted address, then gets the proxy bytecode and constructor arguments,
    ///      and finally calls `_deployProxy` to perform the actual deployment.
    /// @param _saltBytes The `bytes32` salt for the CREATE2 deployment.
    /// @param _initialManager The address to be set as the initial manager in the proxy's constructor.
    /// @return address The address of the newly deployed `SMARTIdentityProxy`.
    function _deployWalletProxy(bytes32 _saltBytes, address _initialManager) private returns (address) {
        address predictedAddr = _computeWalletProxyAddress(_saltBytes, _initialManager);
        (bytes memory proxyBytecode, bytes memory constructorArgs) = _getWalletProxyAndConstructorArgs(_initialManager);
        return _deployProxy(predictedAddr, proxyBytecode, constructorArgs, _saltBytes);
    }

    /// @notice Internal function to deploy a `SMARTTokenIdentityProxy` using CREATE2.
    /// @dev Similar to `_deployWalletProxy` but for token identities, using `_computeTokenProxyAddress` and
    /// `_getTokenProxyAndConstructorArgs`.
    /// @param _saltBytes The `bytes32` salt for the CREATE2 deployment.
    /// @param _accessManager The address of the access manager contract that will be set as the initial owner/manager
    /// @return address The address of the newly deployed `SMARTTokenIdentityProxy`.
    function _deployTokenProxy(bytes32 _saltBytes, address _accessManager) private returns (address) {
        address predictedAddr = _computeTokenProxyAddress(_saltBytes, _accessManager);
        (bytes memory proxyBytecode, bytes memory constructorArgs) = _getTokenProxyAndConstructorArgs(_accessManager);
        return _deployProxy(predictedAddr, proxyBytecode, constructorArgs, _saltBytes);
    }

    /// @notice Internal helper to get the creation bytecode and encoded constructor arguments for `SMARTIdentityProxy`.
    /// @dev The constructor of `SMARTIdentityProxy` takes the `_system` address (from factory state) and
    /// `_initialManager`.
    /// @param _initialManager The address to be encoded as the initial manager argument.
    /// @return proxyBytecode The creation bytecode of `SMARTIdentityProxy`.
    /// @return constructorArgs The ABI-encoded constructor arguments (`_system`, `_initialManager`).
    function _getWalletProxyAndConstructorArgs(address _initialManager)
        private
        view
        returns (bytes memory proxyBytecode, bytes memory constructorArgs)
    {
        proxyBytecode = type(SMARTIdentityProxy).creationCode;
        constructorArgs = abi.encode(_system, _initialManager);
        // No explicit return needed due to named return variables
    }

    /// @notice Internal helper to get the creation bytecode and encoded constructor arguments for
    /// `SMARTTokenIdentityProxy`.
    /// @dev The constructor of `SMARTTokenIdentityProxy` takes the `_system` address (from factory state) and
    /// `_accessManager`.
    /// @param _accessManager The address of the access manager contract that will be set as the initial owner/manager
    /// @return proxyBytecode The creation bytecode of `SMARTTokenIdentityProxy`.
    /// @return constructorArgs The ABI-encoded constructor arguments (`_system`, `_accessManager`).
    function _getTokenProxyAndConstructorArgs(address _accessManager)
        private
        view
        returns (bytes memory proxyBytecode, bytes memory constructorArgs)
    {
        proxyBytecode = type(SMARTTokenIdentityProxy).creationCode;
        constructorArgs = abi.encode(_system, _accessManager);
        // No explicit return needed due to named return variables
    }

    /// @notice Core internal function to deploy a proxy contract using `Create2.deploy`.
    /// @dev It concatenates the `_proxyBytecode` with `_constructorArgs` to form the full deployment bytecode.
    ///      Then, it calls `Create2.deploy` with 0 ETH value, the `_saltBytes`, and the deployment bytecode.
    ///      Crucially, it verifies that the `deployedAddress` matches the `_predictedAddr`.
    ///      If they don't match, it reverts with `DeploymentAddressMismatch()`, indicating a severe issue.
    /// @param _predictedAddr The pre-calculated address where the contract is expected to be deployed.
    /// @param _proxyBytecode The creation bytecode of the proxy contract (without constructor arguments).
    /// @param _constructorArgs The ABI-encoded constructor arguments for the proxy.
    /// @param _saltBytes The `bytes32` salt for the CREATE2 deployment.
    /// @return address The address of the successfully deployed proxy contract.
    function _deployProxy(
        address _predictedAddr,
        bytes memory _proxyBytecode,
        bytes memory _constructorArgs,
        bytes32 _saltBytes
    )
        private
        returns (address)
    {
        // slither-disable-next-line encode-packed-collision: Standard pattern for Create2 deployment bytecode.
        bytes memory deploymentBytecode = abi.encodePacked(_proxyBytecode, _constructorArgs);

        address deployedAddress = Create2.deploy(0, _saltBytes, deploymentBytecode);

        if (deployedAddress != _predictedAddr) revert DeploymentAddressMismatch();
        return deployedAddress;
    }

    // --- Context Overrides (ERC2771) ---
    /// @dev Overrides `_msgSender()` to support meta-transactions via ERC2771. If the call is relayed
    ///      by a trusted forwarder, this will return the original sender, not the forwarder.
    ///      Otherwise, it returns `msg.sender` as usual.
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /// @dev Overrides `_msgData()` to support meta-transactions via ERC2771. If the call is relayed,
    ///      this returns the original call data. Otherwise, it returns `msg.data`.
    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    /// @dev Internal function related to ERC2771 context, indicating the length of the suffix
    ///      appended to calldata by a trusted forwarder (usually the sender's address).
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
    /// @notice Checks if the contract supports a given interface ID.
    /// @dev This function is part of the ERC165 standard, allowing other contracts to query what interfaces this
    /// contract implements.
    /// It declares support for the `ISMARTIdentityFactory` interface and any interfaces supported by its parent
    /// contracts
    /// (like `AccessControlEnumerableUpgradeable` and `ERC165Upgradeable`).
    /// @param interfaceId The interface identifier (bytes4) to check.
    /// @return `true` if the contract supports the `interfaceId`, `false` otherwise.
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
