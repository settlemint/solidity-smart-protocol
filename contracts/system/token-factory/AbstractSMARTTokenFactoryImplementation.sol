// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { AccessControlEnumerableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ISMARTTokenFactory } from "./ISMARTTokenFactory.sol";

/// @title SMARTTokenFactory - Contract for managing token registries with role-based access control
/// @notice This contract provides functionality for registering tokens and checking their registration status,
/// managed by roles defined in AccessControl. It also supports deploying proxy contracts using CREATE2.
/// @dev Inherits from AccessControl and ERC2771Context for role management and meta-transaction support.
/// @custom:security-contact support@settlemint.com

abstract contract AbstractSMARTTokenFactoryImplementation is
    ERC2771ContextUpgradeable,
    AccessControlEnumerableUpgradeable,
    ISMARTTokenFactory
{
    /// @notice Role identifier for accounts permitted to register and unregister tokens.
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    /// @notice Custom errors for the factory contract
    /// @dev Defines custom error types used by the contract for various failure conditions.
    error InvalidTokenAddress();
    /// @notice Error for when the provided token address is the zero address.
    error TokenAlreadyRegistered(address token);
    /// @notice Error for attempting to register an already registered token.
    error TokenNotRegistered(address token);
    /// @notice Error for attempting to unregister a token that is not registered.
    error InvalidImplementationAddress();
    /// @notice Error for when the provided token implementation address is the zero address.
    error ProxyCreationFailed(); // Added for CREATE2
    /// @notice Error when a CREATE2 proxy deployment fails.
    error ProxyAddressAlreadyInUse(address predictedAddress); // Added for CREATE2
    /// @notice Error when a predicted CREATE2 address is already marked as deployed by this factory.

    /// @notice Mapping indicating whether a token address is registered.
    /// @dev Stores a boolean value for each token address, true if registered, false otherwise.
    mapping(address tokenAddress => bool isRegistered) public isTokenRegistered;

    /// @notice Mapping indicating whether a proxy address was deployed by this factory.
    /// @dev Stores a boolean value for each proxy address, true if deployed by this factory.
    mapping(address proxyAddress => bool isProxyDeployedByFactory) public isProxyDeployedByFactory; // Added for
        // CREATE2

    /// @notice Emitted when the token implementation address is updated.
    /// @param oldImplementation The address of the old token implementation.
    /// @param newImplementation The address of the new token implementation.
    event TokenImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);

    /// @notice Emitted when a new proxy contract is created using CREATE2.
    /// @param proxyAddress The address of the newly created proxy.
    /// @param salt The salt used for the CREATE2 deployment.
    /// @param tokenTypeIdentifier A string identifying the type of token proxy created (e.g., "SMARTBondProxy").
    event ProxyCreated( // Added for CREATE2
    address indexed proxyAddress, bytes32 indexed salt, string tokenTypeIdentifier);

    // --- State Variables ---

    /// @notice Address of the underlying token implementation contract.
    /// @dev This address points to the contract that holds the core logic for token operations.
    address internal _tokenImplementation;

    /// @notice Constructor for the token factory implementation.
    /// @param forwarder The address of the trusted forwarder for meta-transactions (ERC2771).
    constructor(address forwarder) payable ERC2771ContextUpgradeable(forwarder) {
        _disableInitializers();
    }

    /// @inheritdoc ISMARTTokenFactory
    /// @param initialAdmin The address to be granted the DEFAULT_ADMIN_ROLE and REGISTRAR_ROLE.
    /// @param tokenImplementation_ The initial address of the token implementation contract.
    function initialize(address initialAdmin, address tokenImplementation_) external override initializer {
        if (initialAdmin == address(0)) {
            revert InvalidTokenAddress(); // Re-using for admin address, consider a more specific error if needed
        }
        if (_tokenImplementation == address(0)) {
            revert InvalidImplementationAddress();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(REGISTRAR_ROLE, initialAdmin);

        _tokenImplementation = tokenImplementation_;
    }

    /// @inheritdoc ISMARTTokenFactory
    /// @return tokenImplementation The address of the token implementation contract.
    function tokenImplementation() public view override returns (address) {
        return _tokenImplementation;
    }

    // --- Mutative functions ---

    /// @notice Updates the address of the token implementation contract.
    /// @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
    ///      It allows changing the underlying contract that handles token logic.
    ///      Emits a {TokenImplementationUpdated} event on success.
    /// @param newImplementation The new address for the token implementation contract. Cannot be the zero address.
    /// @custom:oz-upgrades-unsafe-allow state-variable-assignment
    function updateTokenImplementation(address newImplementation) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newImplementation == address(0)) {
            revert InvalidImplementationAddress();
        }
        address oldImplementation = _tokenImplementation;
        _tokenImplementation = newImplementation;
        emit TokenImplementationUpdated(oldImplementation, newImplementation);
    }

    // --- CREATE2 Helper Functions ---

    /// @notice Calculates the salt for CREATE2 deployment.
    /// @dev Combines the name and symbol into a unique salt value.
    ///      Can be overridden by derived contracts for custom salt calculation.
    /// @param nameForSalt The name component for the salt.
    /// @param symbolForSalt The symbol component for the salt.
    /// @return The calculated salt for CREATE2 deployment.
    function _calculateSalt(
        string memory nameForSalt,
        string memory symbolForSalt
    )
        internal
        pure
        virtual
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(nameForSalt, symbolForSalt));
    }

    /// @notice Predicts the deployment address of a proxy using CREATE2.
    /// @dev Internal function to compute the address without performing deployment.
    /// @param proxyCreationCode The creation bytecode of the proxy contract.
    /// @param encodedConstructorArgs ABI-encoded constructor arguments for the proxy.
    /// @param nameForSalt The name component for the salt.
    /// @param symbolForSalt The symbol component for the salt.
    /// @return predictedAddress The predicted address where the proxy would be deployed.
    function _predictProxyAddressCREATE2(
        bytes memory proxyCreationCode,
        bytes memory encodedConstructorArgs,
        string memory nameForSalt,
        string memory symbolForSalt
    )
        internal
        view
        returns (address predictedAddress)
    {
        bytes32 salt = _calculateSalt(nameForSalt, symbolForSalt);
        bytes memory fullCreationCode = bytes.concat(proxyCreationCode, encodedConstructorArgs);
        bytes32 initCodeHash = keccak256(fullCreationCode);
        bytes32 saltedHash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, initCodeHash));
        predictedAddress = address(uint160(uint256(saltedHash)));
    }

    /// @notice Deploys a proxy contract using CREATE2.
    /// @dev This internal function handles the prediction, deployment, and registration of the proxy.
    /// @param proxyCreationCode The creation bytecode of the proxy contract.
    /// @param encodedConstructorArgs ABI-encoded constructor arguments for the proxy.
    /// @param nameForSalt The name component for the salt calculation.
    /// @param symbolForSalt The symbol component for the salt calculation.
    /// @param tokenTypeIdentifier A string to identify the type of token proxy created in the event.
    /// @return deployedAddress The address of the newly deployed proxy contract.
    function _deployProxyCREATE2(
        bytes memory proxyCreationCode,
        bytes memory encodedConstructorArgs,
        string memory nameForSalt,
        string memory symbolForSalt,
        string memory tokenTypeIdentifier
    )
        internal
        returns (address deployedAddress)
    {
        address predictedAddress =
            _predictProxyAddressCREATE2(proxyCreationCode, encodedConstructorArgs, nameForSalt, symbolForSalt);

        if (isProxyDeployedByFactory[predictedAddress]) {
            revert ProxyAddressAlreadyInUse(predictedAddress);
        }

        bytes32 salt = _calculateSalt(nameForSalt, symbolForSalt);
        bytes memory fullCreationCode = bytes.concat(proxyCreationCode, encodedConstructorArgs);

        assembly {
            deployedAddress := create2(0, add(fullCreationCode, 0x20), mload(fullCreationCode), salt)
        }

        if (deployedAddress == address(0)) {
            revert ProxyCreationFailed();
        }

        // Sanity check: deployed address must match predicted address
        if (deployedAddress != predictedAddress) {
            // This should ideally not happen if calculations and salt are consistent.
            // It might indicate an unexpected issue.
            revert ProxyCreationFailed();
        }

        isProxyDeployedByFactory[deployedAddress] = true;
        emit ProxyCreated(deployedAddress, salt, tokenTypeIdentifier);

        return deployedAddress;
    }

    // --- ERC2771Context Overrides ---

    /// @dev Overrides the default implementation of _msgSender() to return the actual sender
    ///      instead of the forwarder address when using ERC2771 context.
    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address) {
        return super._msgSender();
    }

    /// @dev Overrides the default implementation of _msgData() to return the actual calldata
    ///      instead of the forwarder calldata when using ERC2771 context.
    function _msgData()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return super._msgData();
    }

    /// @dev Overrides the default implementation of _contextSuffixLength() to return the actual suffix length
    ///      instead of the forwarder suffix length when using ERC2771 context.
    function _contextSuffixLength()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return super._contextSuffixLength();
    }
}
