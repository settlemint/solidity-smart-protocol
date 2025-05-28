// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ISMARTTokenFactory } from "./ISMARTTokenFactory.sol";
import { ISMART } from "../../interface/ISMART.sol";
import { ISMARTCustodian } from "../../extensions/custodian/ISMARTCustodian.sol";
import { SMARTTokenAccessManagerProxy } from "../access-manager/SMARTTokenAccessManagerProxy.sol";
import { ISMARTTokenAccessManager } from "../../extensions/access-managed/ISMARTTokenAccessManager.sol";
import { ISMARTIdentityRegistry } from "../../interface/ISMARTIdentityRegistry.sol";
import { ISMARTCompliance } from "../../interface/ISMARTCompliance.sol";
import { ISMARTSystem } from "../ISMARTSystem.sol";
import { ISMARTIdentityFactory } from "../identity-factory/ISMARTIdentityFactory.sol";
import { SMARTSystemRoles } from "../SMARTSystemRoles.sol";
import { SMARTRoles } from "../../assets/SMARTRoles.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

/// @title SMARTTokenFactory - Contract for managing token registries with role-based access control
/// @notice This contract provides functionality for registering tokens and checking their registration status,
/// managed by roles defined in AccessControl. It also supports deploying proxy contracts using CREATE2.
/// @dev Inherits from AccessControl and ERC2771Context for role management and meta-transaction support.
/// @custom:security-contact support@settlemint.com

abstract contract AbstractSMARTTokenFactoryImplementation is
    ERC2771ContextUpgradeable,
    ERC165Upgradeable,
    AccessControlUpgradeable,
    ISMARTTokenFactory
{
    /// @notice Error when a predicted CREATE2 address is already marked as deployed by this factory.

    /// @notice Mapping indicating whether a token address was deployed by this factory.
    /// @dev Stores a boolean value for each token address, true if deployed by this factory.
    mapping(address tokenAddress => bool isFactoryToken) public isFactoryToken; // Added for
        // CREATE2

    /// @notice Mapping indicating whether an access manager address was deployed by this factory.
    /// @dev Stores a boolean value for each access manager address, true if deployed by this factory.
    mapping(address accessManagerAddress => bool isFactoryAccessManager) public isFactoryAccessManager;

    // -- Errors --
    /// @notice Custom errors for the factory contract
    /// @dev Defines custom error types used by the contract for various failure conditions.

    error InvalidTokenAddress();
    /// @notice Error for attempting to unregister a token that is not registered.
    error InvalidImplementationAddress();
    /// @notice Error for when the provided token implementation address is the zero address.
    error ProxyCreationFailed(); // Added for CREATE2
    /// @notice Error when a CREATE2 proxy deployment fails.
    error AddressAlreadyDeployed(address predictedAddress); // Added for CREATE2
    /// @notice Error when a predicted CREATE2 address for an access manager is already marked as deployed by this
    /// factory.
    error AccessManagerAlreadyDeployed(address predictedAddress);

    // --- State Variables ---

    /// @dev The address of the `ISMARTSystem` contract.
    address internal _systemAddress;

    /// @notice Address of the underlying token implementation contract.
    /// @dev This address points to the contract that holds the core logic for token operations.
    address internal _tokenImplementation;

    /// @notice Constructor for the token factory implementation.
    /// @param forwarder The address of the trusted forwarder for meta-transactions (ERC2771).
    constructor(address forwarder) ERC2771ContextUpgradeable(forwarder) {
        _disableInitializers();
    }

    /// @inheritdoc ISMARTTokenFactory
    /// @param systemAddress The address of the `ISMARTSystem` contract.
    /// @param tokenImplementation_ The initial address of the token implementation contract.
    /// @param initialAdmin The address to be granted the DEFAULT_ADMIN_ROLE and TOKEN_DEPLOYER_ROLE.
    function initialize(
        address systemAddress,
        address tokenImplementation_,
        address initialAdmin
    )
        public
        virtual
        override
        initializer
    {
        if (initialAdmin == address(0)) {
            revert InvalidTokenAddress(); // Re-using for admin address, consider a more specific error if needed
        }
        if (
            tokenImplementation_ == address(0)
                && IERC165(tokenImplementation_).supportsInterface(type(ISMART).interfaceId)
        ) {
            revert InvalidImplementationAddress();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(SMARTSystemRoles.TOKEN_DEPLOYER_ROLE, initialAdmin);

        _tokenImplementation = tokenImplementation_;
        _systemAddress = systemAddress;
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
        emit TokenImplementationUpdated(_msgSender(), oldImplementation, newImplementation);
    }

    // --- Internal Functions ---
    function _identityRegistry() internal view returns (ISMARTIdentityRegistry) {
        return ISMARTIdentityRegistry(ISMARTSystem(_systemAddress).identityRegistryProxy());
    }

    function _compliance() internal view returns (ISMARTCompliance) {
        return ISMARTCompliance(ISMARTSystem(_systemAddress).complianceProxy());
    }

    /// @notice Calculates the salt for CREATE2 deployment.
    /// @dev Can be overridden by derived contracts for custom salt calculation.
    /// @param systemAddress The system address to prevent cross-system collisions.
    /// @param saltInputData The ABI encoded data to be used for salt calculation.
    /// @return The calculated salt for CREATE2 deployment.
    function _calculateSalt(address systemAddress, bytes memory saltInputData) internal pure returns (bytes32) {
        return keccak256(abi.encode(systemAddress, saltInputData));
    }

    /// @notice Calculates the salt for CREATE2 deployment of an access manager.
    /// @dev Prepends "AccessManagerSalt" to the provided saltInputData.
    /// @param systemAddress The system address to prevent cross-system collisions.
    /// @param saltInputData The ABI encoded data to be used for salt calculation.
    /// @return The calculated salt for access manager CREATE2 deployment.
    function _calculateAccessManagerSalt(
        address systemAddress,
        bytes memory saltInputData
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(systemAddress, "AccessManagerSalt", saltInputData));
    }

    /// @notice Builds salt input data for token creation.
    /// @dev Internal helper to build the salt input for access manager and related operations.
    /// @param name_ The name of the token.
    /// @param symbol_ The symbol of the token.
    /// @param decimals_ The number of decimals for the token.
    /// @return The ABI encoded salt input data.
    function _buildSaltInput(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(name_, symbol_, decimals_);
    }

    /// @notice Prepares the data required for access manager creation using CREATE2.
    /// @dev Internal helper function to calculate salt and full creation code.
    /// @param accessManagerSaltInputData The ABI encoded data to be used for salt calculation for the access manager.
    /// @return salt The calculated salt for CREATE2 deployment.
    /// @return fullCreationCode The complete bytecode for deploying the access manager.
    function _prepareAccessManagerCreationData(bytes memory accessManagerSaltInputData)
        internal
        view
        returns (bytes32 salt, bytes memory fullCreationCode)
    {
        salt = _calculateAccessManagerSalt(_systemAddress, accessManagerSaltInputData);
        address[] memory initialAdmins = new address[](1); // Factory is initial admin
        initialAdmins[0] = address(this);
        bytes memory constructorArgs = abi.encode(_systemAddress, initialAdmins);
        bytes memory bytecode = type(SMARTTokenAccessManagerProxy).creationCode;
        fullCreationCode = bytes.concat(bytecode, constructorArgs);
    }

    /// @notice Predicts the deployment address of an access manager using CREATE2.
    /// @param accessManagerSaltInputData The ABI encoded data to be used for salt calculation for the access manager.
    /// @return predictedAddress The predicted address where the access manager would be deployed.
    function _predictAccessManagerAddress(bytes memory accessManagerSaltInputData)
        internal
        view
        returns (address predictedAddress)
    {
        (bytes32 salt, bytes memory fullCreationCode) = _prepareAccessManagerCreationData(accessManagerSaltInputData);
        bytes32 bytecodeHash = keccak256(fullCreationCode);
        predictedAddress = Create2.computeAddress(salt, bytecodeHash, address(this));
        return predictedAddress;
    }

    /// @notice Creates a new access manager for a token using CREATE2.
    /// @dev Deploys SMARTTokenAccessManagerProxy with a deterministic address.
    /// @param accessManagerSaltInputData The ABI encoded data to be used for salt calculation for the access manager.
    /// @return accessManager The instance of the newly created access manager.
    function _createAccessManager(bytes memory accessManagerSaltInputData)
        internal
        virtual
        onlyRole(SMARTSystemRoles.TOKEN_DEPLOYER_ROLE)
        returns (ISMARTTokenAccessManager)
    {
        // Calculate salt and creation code once
        bytes32 salt = _calculateAccessManagerSalt(_systemAddress, accessManagerSaltInputData);

        // Use inline array assembly for gas efficiency
        address[] memory initialAdmins;
        assembly {
            initialAdmins := mload(0x40)
            mstore(0x40, add(initialAdmins, 0x40))
            mstore(initialAdmins, 1)
            mstore(add(initialAdmins, 0x20), address())
        }

        bytes memory constructorArgs = abi.encode(_systemAddress, initialAdmins);
        bytes memory bytecode = type(SMARTTokenAccessManagerProxy).creationCode;
        bytes memory fullCreationCode = bytes.concat(bytecode, constructorArgs);

        // Predict address using pre-calculated data
        bytes32 bytecodeHash = keccak256(fullCreationCode);
        address predictedAccessManagerAddress = Create2.computeAddress(salt, bytecodeHash, address(this));

        if (isFactoryAccessManager[predictedAccessManagerAddress]) {
            revert AccessManagerAlreadyDeployed(predictedAccessManagerAddress);
        }

        address deployedAddress = Create2.deploy(0, salt, fullCreationCode);

        if (deployedAddress != predictedAccessManagerAddress) {
            revert ProxyCreationFailed(); // Could be more specific: AccessManagerCreationFailed
        }

        isFactoryAccessManager[deployedAddress] = true;
        ISMARTTokenAccessManager accessManager = ISMARTTokenAccessManager(deployedAddress);

        return accessManager;
    }

    /// @notice Deploys a proxy contract using CREATE2.
    /// @dev This internal function handles the prediction and deployment of the asset proxy.
    ///      The proxy is deployed uninitialized, pointing to the current `_tokenImplementation`.
    /// @param proxyCreationCode The creation bytecode of the proxy contract.
    /// @param encodedConstructorArgs ABI-encoded constructor arguments for the proxy.
    /// @param tokenSaltInputData The ABI encoded data to be used for salt calculation for the token.
    /// @param accessManager The address of the access manager.
    /// @return deployedAddress The address of the newly deployed proxy contract.
    function _deployToken(
        bytes memory proxyCreationCode,
        bytes memory encodedConstructorArgs,
        bytes memory tokenSaltInputData,
        address accessManager
    )
        internal
        onlyRole(SMARTSystemRoles.TOKEN_DEPLOYER_ROLE)
        returns (address deployedAddress)
    {
        // Calculate salt and creation code once
        bytes32 salt = _calculateSalt(_systemAddress, tokenSaltInputData);
        bytes memory fullCreationCode = bytes.concat(proxyCreationCode, encodedConstructorArgs);

        // Predict address using pre-calculated data
        bytes32 bytecodeHash = keccak256(fullCreationCode);
        address predictedAddress = Create2.computeAddress(salt, bytecodeHash, address(this));

        if (isFactoryToken[predictedAddress]) {
            revert AddressAlreadyDeployed(predictedAddress);
        }

        deployedAddress = Create2.deploy(0, salt, fullCreationCode);

        if (deployedAddress != predictedAddress) {
            revert ProxyCreationFailed();
        }

        isFactoryToken[deployedAddress] = true;

        _finalizeTokenCreation(deployedAddress, accessManager);

        return deployedAddress;
    }

    /// @notice Predicts the deployment address of a proxy using CREATE2.
    /// @dev Internal function to compute the address without performing deployment.
    ///      Assumes the proxy constructor takes (address _logic, bytes memory _data).
    /// @param proxyCreationCode The creation bytecode of the proxy contract.
    /// @param encodedConstructorArgs ABI-encoded constructor arguments for the proxy.
    /// @param tokenSaltInputData The ABI encoded data to be used for salt calculation for the token.
    /// @return predictedAddress The predicted address where the proxy would be deployed.
    function _predictProxyAddress(
        bytes memory proxyCreationCode,
        bytes memory encodedConstructorArgs,
        bytes memory tokenSaltInputData
    )
        internal
        view
        returns (address predictedAddress)
    {
        bytes32 salt = _calculateSalt(_systemAddress, tokenSaltInputData);
        bytes memory fullCreationCode = bytes.concat(proxyCreationCode, encodedConstructorArgs);
        bytes32 bytecodeHash = keccak256(fullCreationCode);
        predictedAddress = Create2.computeAddress(salt, bytecodeHash, address(this));
    }

    /// @notice Finalizes the token creation process after deployment and initialization.
    /// @dev Sets up token identity, on-chain ID, and necessary roles.
    /// @param tokenAddress The address of the deployed token (proxy).
    /// @param accessManagerAddress The address of the token's access manager.
    function _finalizeTokenCreation(address tokenAddress, address accessManagerAddress) internal {
        ISMARTSystem system_ = ISMARTSystem(_systemAddress);
        ISMARTIdentityFactory identityFactory_ = ISMARTIdentityFactory(system_.identityFactoryProxy());
        address tokenIdentity = identityFactory_.createTokenIdentity(tokenAddress, accessManagerAddress);

        IAccessControl accessManagerCtrl = IAccessControl(accessManagerAddress);

        // Make sure the creator has admin rights on the access manager.
        accessManagerCtrl.grantRole(DEFAULT_ADMIN_ROLE, _msgSender());

        // Grant the token factory the TOKEN_GOVERNANCE_ROLE to set the onchainID.
        accessManagerCtrl.grantRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE, address(this));
        ISMART(tokenAddress).setOnchainID(tokenIdentity);
        accessManagerCtrl.renounceRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE, address(this));
        accessManagerCtrl.renounceRole(DEFAULT_ADMIN_ROLE, address(this));

        // Make it possible that the token can register token identities, only needed for Custodian recovery.
        if (IERC165(tokenAddress).supportsInterface(type(ISMARTCustodian).interfaceId)) {
            IAccessControl(system_.identityRegistryProxy()).grantRole(SMARTSystemRoles.REGISTRAR_ROLE, tokenAddress);
        }

        emit TokenAssetCreated(_msgSender(), tokenAddress, tokenIdentity, accessManagerAddress);
    }

    // --- ERC165 Overrides ---

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable, ERC165Upgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(ISMARTTokenFactory).interfaceId || super.supportsInterface(interfaceId);
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
