// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Interface imports
import { ISMARTTopicSchemeRegistry } from "./ISMARTTopicSchemeRegistry.sol";

// Constants
import { SMARTSystemRoles } from "../SMARTSystemRoles.sol";

/// @title SMART Topic Scheme Registry Implementation
/// @author SettleMint Tokenization Services
/// @notice Implementation for managing topic schemes with their signatures for data encoding/decoding
/// @dev This contract manages the registration and lifecycle of topic schemes used for claim data structures
contract SMARTTopicSchemeRegistryImplementation is
    Initializable,
    ERC165Upgradeable,
    ERC2771ContextUpgradeable,
    AccessControlUpgradeable,
    ISMARTTopicSchemeRegistry
{
    // --- Storage Variables ---
    /// @notice Mapping from topic ID to topic scheme information
    /// @dev Maps topicId => TopicScheme struct containing id, signature, and existence flag
    mapping(uint256 topicId => TopicScheme scheme) private _topicSchemes;

    /// @notice Mapping from topic name hash to topic ID for name-based lookups
    /// @dev Maps keccak256(abi.encodePacked(name)) => topicId for efficient name-based retrieval
    mapping(bytes32 nameHash => uint256 topicId) private _nameHashToTopicId;

    /// @notice Array storing all registered topic IDs for enumeration
    /// @dev Allows iteration over all registered topic schemes
    uint256[] private _topicIds;

    /// @notice Mapping from topic ID to its index in the _topicIds array (plus one)
    /// @dev Used for efficient removal from _topicIds array using swap-and-pop technique
    /// Value of 0 means the topic ID is not in the array, non-zero values represent (actualIndex + 1)
    mapping(uint256 topicId => uint256 indexPlusOne) private _topicIdIndex;

    /// @notice Mapping to store topic names for event emission (gas-optimized storage)
    /// @dev Maps topicId => name string, only used for events and removal operations
    mapping(uint256 topicId => string name) private _topicNames;

    // --- Custom Errors ---
    /// @notice Error thrown when attempting to register a topic scheme with an invalid (zero) topic ID
    error InvalidTopicId();

    /// @notice Error thrown when attempting to register a topic scheme with an empty name
    error EmptyName();

    /// @notice Error thrown when attempting to register a topic scheme with an empty signature
    error EmptySignature();

    /// @notice Error thrown when attempting to register a topic scheme that already exists
    /// @param topicId The topic ID that already exists
    error TopicSchemeAlreadyExists(uint256 topicId);

    /// @notice Error thrown when attempting to register a topic scheme with a name that already exists
    /// @param name The name that already exists
    error TopicSchemeNameAlreadyExists(string name);

    /// @notice Error thrown when attempting to operate on a topic scheme that doesn't exist
    /// @param topicId The topic ID that doesn't exist
    error TopicSchemeDoesNotExist(uint256 topicId);

    /// @notice Error thrown when attempting to operate on a topic scheme that doesn't exist by name
    /// @param name The name that doesn't exist
    error TopicSchemeDoesNotExistByName(string name);

    /// @notice Error thrown when a topic ID is not found in the enumeration array during removal
    /// @param topicId The topic ID that was not found
    error TopicIdNotFoundInArray(uint256 topicId);

    /// @notice Error thrown when attempting to update a topic scheme with the same signature
    /// @param topicId The topic ID being updated
    /// @param signature The signature that is already set
    error SignatureUnchanged(uint256 topicId, string signature);

    /// @notice Error thrown when input arrays have mismatched lengths
    /// @param topicIdsLength The length of the topic IDs array
    /// @param namesLength The length of the names array
    /// @param signaturesLength The length of the signatures array
    error ArrayLengthMismatch(uint256 topicIdsLength, uint256 namesLength, uint256 signaturesLength);

    /// @notice Error thrown when attempting batch operations with empty arrays
    error EmptyArraysProvided();

    // --- Constructor ---
    /// @notice Constructor for the SMARTTopicSchemeRegistryImplementation
    /// @dev Initializes ERC2771Context with trusted forwarder and disables initializers for UUPS pattern
    /// @param trustedForwarder The address of the trusted forwarder for meta-transactions
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
        _disableInitializers();
    }

    // --- Initializer ---
    /// @notice Initializes the SMARTTopicSchemeRegistryImplementation contract
    /// @dev Sets up access control and grants initial roles to the admin
    /// @param initialAdmin The address that will receive admin and registrar roles
    function initialize(address initialAdmin) public initializer {
        __ERC165_init_unchained();
        __AccessControl_init_unchained();

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(SMARTSystemRoles.REGISTRAR_ROLE, initialAdmin);
    }

    // --- Topic Scheme Management Functions ---

    /// @inheritdoc ISMARTTopicSchemeRegistry
    function registerTopicScheme(
        uint256 topicId,
        string calldata name,
        string calldata signature
    )
        external
        override
        onlyRole(SMARTSystemRoles.REGISTRAR_ROLE)
    {
        if (topicId == 0) revert InvalidTopicId();
        if (bytes(name).length == 0) revert EmptyName();
        if (bytes(signature).length == 0) revert EmptySignature();
        if (_topicSchemes[topicId].exists) revert TopicSchemeAlreadyExists(topicId);

        bytes32 nameHash = keccak256(abi.encodePacked(name));
        if (_nameHashToTopicId[nameHash] != 0) revert TopicSchemeNameAlreadyExists(name);

        // Store the topic scheme (no nameHash stored, computed on-demand)
        _topicSchemes[topicId] = TopicScheme({ topicId: topicId, signature: signature, exists: true });

        // Store name hash mapping for lookups
        _nameHashToTopicId[nameHash] = topicId;

        // Store name for events (separate mapping to avoid storing in main struct)
        _topicNames[topicId] = name;

        // Add to enumeration array
        _topicIds.push(topicId);
        _topicIdIndex[topicId] = _topicIds.length; // Store index + 1

        emit TopicSchemeRegistered(_msgSender(), topicId, name, signature);
    }

    /// @inheritdoc ISMARTTopicSchemeRegistry
    function batchRegisterTopicSchemes(
        uint256[] calldata topicIds,
        string[] calldata names,
        string[] calldata signatures
    )
        external
        override
        onlyRole(SMARTSystemRoles.REGISTRAR_ROLE)
    {
        uint256 topicIdsLength = topicIds.length;
        uint256 namesLength = names.length;
        uint256 signaturesLength = signatures.length;

        // Validate input arrays
        if (topicIdsLength == 0) revert EmptyArraysProvided();
        if (topicIdsLength != namesLength || topicIdsLength != signaturesLength) {
            revert ArrayLengthMismatch(topicIdsLength, namesLength, signaturesLength);
        }

        // Cache the current length to avoid reading from storage in each iteration
        uint256 currentArrayLength = _topicIds.length;

        // Cache storage variables accessed in loop
        mapping(uint256 => TopicScheme) storage topicSchemes_ = _topicSchemes;
        mapping(bytes32 => uint256) storage nameHashToTopicId_ = _nameHashToTopicId;
        mapping(uint256 => string) storage topicNames_ = _topicNames;
        uint256[] storage topicIds_ = _topicIds;
        mapping(uint256 => uint256) storage topicIdIndex_ = _topicIdIndex;

        // Process each topic scheme registration
        for (uint256 i = 0; i < topicIdsLength;) {
            uint256 topicId = topicIds[i];
            string calldata name = names[i];
            string calldata signature = signatures[i];

            // Validate individual topic scheme (same validation as single register)
            if (topicId == 0) revert InvalidTopicId();
            if (bytes(name).length == 0) revert EmptyName();
            if (bytes(signature).length == 0) revert EmptySignature();
            if (topicSchemes_[topicId].exists) revert TopicSchemeAlreadyExists(topicId);

            bytes32 nameHash = keccak256(abi.encodePacked(name));
            if (nameHashToTopicId_[nameHash] != 0) revert TopicSchemeNameAlreadyExists(name);

            // Store the topic scheme (no nameHash stored)
            topicSchemes_[topicId] = TopicScheme({ topicId: topicId, signature: signature, exists: true });

            // Store name hash mapping for lookups
            nameHashToTopicId_[nameHash] = topicId;

            // Store name for events
            topicNames_[topicId] = name;

            // Add to enumeration array
            topicIds_.push(topicId);
            currentArrayLength++;
            topicIdIndex_[topicId] = currentArrayLength; // Use cached length instead of reading from storage

            // Emit individual event for each registration
            emit TopicSchemeRegistered(_msgSender(), topicId, name, signature);

            unchecked {
                ++i;
            }
        }

        // Emit batch event
        emit TopicSchemesBatchRegistered(_msgSender(), topicIds, names, signatures);
    }

    /// @inheritdoc ISMARTTopicSchemeRegistry
    function updateTopicScheme(
        uint256 topicId,
        string calldata newSignature
    )
        external
        override
        onlyRole(SMARTSystemRoles.REGISTRAR_ROLE)
    {
        if (!_topicSchemes[topicId].exists) revert TopicSchemeDoesNotExist(topicId);
        if (bytes(newSignature).length == 0) revert EmptySignature();

        string memory oldSignature = _topicSchemes[topicId].signature;
        if (keccak256(bytes(oldSignature)) == keccak256(bytes(newSignature))) {
            revert SignatureUnchanged(topicId, newSignature);
        }

        _topicSchemes[topicId].signature = newSignature;

        emit TopicSchemeUpdated(_msgSender(), topicId, _topicNames[topicId], oldSignature, newSignature);
    }

    /// @inheritdoc ISMARTTopicSchemeRegistry
    function removeTopicScheme(uint256 topicId) external override onlyRole(SMARTSystemRoles.REGISTRAR_ROLE) {
        if (!_topicSchemes[topicId].exists) revert TopicSchemeDoesNotExist(topicId);

        // Get the name before deletion for cleanup and event
        string memory name = _topicNames[topicId];
        // Compute hash from stored name instead of reading from struct
        bytes32 nameHash = keccak256(abi.encodePacked(name));

        // Remove from enumeration array using swap-and-pop
        _removeTopicIdFromArray(topicId);

        // Remove name hash mapping
        delete _nameHashToTopicId[nameHash];

        // Remove name storage
        delete _topicNames[topicId];

        // Delete the topic scheme
        delete _topicSchemes[topicId];

        emit TopicSchemeRemoved(_msgSender(), topicId, name);
    }

    // --- View Functions ---

    /// @inheritdoc ISMARTTopicSchemeRegistry
    function hasTopicScheme(uint256 topicId) external view override returns (bool exists) {
        return _topicSchemes[topicId].exists;
    }

    /// @inheritdoc ISMARTTopicSchemeRegistry
    function hasTopicSchemeByName(string calldata name) external view override returns (bool exists) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        return _nameHashToTopicId[nameHash] != 0;
    }

    /// @inheritdoc ISMARTTopicSchemeRegistry
    function getTopicSchemeSignature(uint256 topicId) external view override returns (string memory signature) {
        if (!_topicSchemes[topicId].exists) revert TopicSchemeDoesNotExist(topicId);
        return _topicSchemes[topicId].signature;
    }

    /// @inheritdoc ISMARTTopicSchemeRegistry
    function getTopicSchemeSignatureByName(string calldata name)
        external
        view
        override
        returns (string memory signature)
    {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        uint256 topicId = _nameHashToTopicId[nameHash];
        if (topicId == 0) revert TopicSchemeDoesNotExistByName(name);
        return _topicSchemes[topicId].signature;
    }

    /// @inheritdoc ISMARTTopicSchemeRegistry
    function getTopicIdByName(string calldata name) external view override returns (uint256 topicId) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        topicId = _nameHashToTopicId[nameHash];
        if (topicId == 0) revert TopicSchemeDoesNotExistByName(name);
        return topicId;
    }

    /// @inheritdoc ISMARTTopicSchemeRegistry
    function getAllTopicIds() external view override returns (uint256[] memory topicIds) {
        return _topicIds;
    }

    /// @inheritdoc ISMARTTopicSchemeRegistry
    function getTopicSchemeCount() external view override returns (uint256 count) {
        return _topicIds.length;
    }

    // --- Internal Helper Functions ---

    /// @notice Removes a topic ID from the enumeration array using swap-and-pop technique
    /// @dev This maintains array compactness by swapping the target element with the last element
    /// @param topicId The topic ID to remove from the array
    function _removeTopicIdFromArray(uint256 topicId) internal {
        uint256 indexPlusOne = _topicIdIndex[topicId];
        if (indexPlusOne == 0) revert TopicIdNotFoundInArray(topicId);

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = _topicIds.length - 1;

        if (index != lastIndex) {
            // Move the last element to the position of the element to be removed
            uint256 lastTopicId = _topicIds[lastIndex];
            _topicIds[index] = lastTopicId;
            _topicIdIndex[lastTopicId] = indexPlusOne; // Update index for moved element
        }

        // Remove the last element and clear the index
        _topicIds.pop();
        delete _topicIdIndex[topicId];
    }

    // --- ERC165 Support ---

    /// @notice Returns true if this contract implements the interface defined by interfaceId
    /// @dev Supports ISMARTTopicSchemeRegistry and inherited interfaces
    /// @param interfaceId The interface identifier to check
    /// @return True if the interface is supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165Upgradeable, AccessControlUpgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(ISMARTTopicSchemeRegistry).interfaceId || super.supportsInterface(interfaceId);
    }

    // --- Meta-transaction Support ---

    /// @notice Returns the sender of the transaction, supporting meta-transactions
    /// @dev Overrides to support ERC2771 meta-transactions
    /// @return The address of the transaction sender
    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address) {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /// @notice Returns the calldata of the transaction, supporting meta-transactions
    /// @dev Overrides to support ERC2771 meta-transactions
    /// @return The calldata of the transaction
    function _msgData()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    /// @notice Returns the context suffix for meta-transactions
    /// @dev Overrides to support ERC2771 meta-transactions
    /// @return The context suffix
    function _contextSuffixLength()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }
}
