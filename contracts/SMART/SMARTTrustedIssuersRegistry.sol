// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { AccessControlDefaultAdminRulesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

// Interface imports
import { IERC3643TrustedIssuersRegistry } from "./interface/ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { IClaimIssuer } from "../onchainid/interface/IClaimIssuer.sol";

// --- Errors ---
error InvalidIssuerAddress();
error NoClaimTopicsProvided();
error IssuerAlreadyExists(address issuerAddress);
error IssuerDoesNotExist(address issuerAddress);
error IssuerNotFoundInTopicList(address issuerAddress, uint256 claimTopic);
error AddressNotFoundInList(address addr);

/// @title SMART Trusted Issuers Registry
/// @notice Upgradeable registry for managing trusted claim issuers and the claim topics they are authorized for,
/// compliant with ERC-3643.
/// @dev Provides efficient lookups for finding trusted issuers associated with specific claim topics.
///      Managed by AccessControl and upgradeable via UUPS.
contract SMARTTrustedIssuersRegistry is
    Initializable,
    IERC3643TrustedIssuersRegistry,
    ERC2771ContextUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    UUPSUpgradeable
{
    // --- Roles ---
    /// @notice Role required to add, remove, or update trusted issuers and their claim topics.
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    // --- Storage Variables ---
    /// @notice Struct holding details for a trusted issuer.
    struct TrustedIssuer {
        address issuer; // Issuer contract address
        uint256[] claimTopics; // Topics this issuer is trusted for
        bool exists; // Flag indicating if the issuer is currently registered
    }

    /// @notice Primary mapping from issuer address => TrustedIssuer struct.
    mapping(address => TrustedIssuer) private _trustedIssuers;
    /// @notice Array storing all trusted issuer addresses for iteration.
    address[] private _issuerAddresses;

    /// @notice Mapping from claim topic => array of issuer addresses trusted for that topic.
    mapping(uint256 => address[]) private _issuersByClaimTopic;
    /// @notice Mapping for efficient removal: claim topic => issuer address => index+1 in `_issuersByClaimTopic[topic]`
    /// array.
    mapping(uint256 => mapping(address => uint256)) private _claimTopicIssuerIndex;

    // --- Events ---
    /// @notice Emitted when a new trusted issuer is added.
    event TrustedIssuerAdded(address indexed _issuer, uint256[] _claimTopics);
    /// @notice Emitted when a trusted issuer is removed.
    event TrustedIssuerRemoved(address indexed _issuer);
    /// @notice Emitted when the claim topics for an existing trusted issuer are updated.
    event ClaimTopicsUpdated(address indexed _issuer, uint256[] _claimTopics);

    // --- Constructor --- (Disable direct construction)
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC2771ContextUpgradeable(address(0)) {
        _disableInitializers();
    }

    // --- Initializer ---
    /// @notice Initializes the trusted issuers registry.
    /// @dev Sets up AccessControl with default admin rules and UUPS upgradeability.
    ///      Grants the initial admin the `DEFAULT_ADMIN_ROLE` and `REGISTRAR_ROLE`.
    /// @param initialAdmin The address for initial admin and registrar roles.
    function initialize(address initialAdmin) public initializer {
        __AccessControl_init();
        __AccessControlDefaultAdminRules_init(3 days, initialAdmin);
        __UUPSUpgradeable_init();
        // ERC2771Context initialized by constructor

        _grantRole(REGISTRAR_ROLE, initialAdmin); // Grant registrar role to initial admin
    }

    // --- Issuer Management Functions (REGISTRAR_ROLE required) ---

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    /// @dev Requires `REGISTRAR_ROLE`.
    function addTrustedIssuer(
        IClaimIssuer _trustedIssuer,
        uint256[] calldata _claimTopics
    )
        external
        override
        onlyRole(REGISTRAR_ROLE)
    {
        address issuerAddress = address(_trustedIssuer);
        if (issuerAddress == address(0)) revert InvalidIssuerAddress();
        if (_claimTopics.length == 0) revert NoClaimTopicsProvided();
        if (_trustedIssuers[issuerAddress].exists) revert IssuerAlreadyExists(issuerAddress);

        // Store issuer details
        _trustedIssuers[issuerAddress] = TrustedIssuer(issuerAddress, _claimTopics, true);
        _issuerAddresses.push(issuerAddress);

        // Add issuer to the lookup mapping for each specified claim topic
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            _addIssuerToClaimTopic(_claimTopics[i], issuerAddress);
        }

        emit TrustedIssuerAdded(issuerAddress, _claimTopics);
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    /// @dev Requires `REGISTRAR_ROLE`.
    function removeTrustedIssuer(IClaimIssuer _trustedIssuer) external override onlyRole(REGISTRAR_ROLE) {
        address issuerAddress = address(_trustedIssuer);
        if (!_trustedIssuers[issuerAddress].exists) revert IssuerDoesNotExist(issuerAddress);

        uint256[] memory topicsToRemove = _trustedIssuers[issuerAddress].claimTopics;

        // Remove issuer from the main list of issuers
        _removeAddressFromList(_issuerAddresses, issuerAddress);

        // Remove issuer from the lookup mapping for each of its associated claim topics
        for (uint256 i = 0; i < topicsToRemove.length; i++) {
            _removeIssuerFromClaimTopic(topicsToRemove[i], issuerAddress);
        }

        // Delete the issuer's main record
        delete _trustedIssuers[issuerAddress];

        emit TrustedIssuerRemoved(issuerAddress);
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    /// @dev Requires `REGISTRAR_ROLE`.
    function updateIssuerClaimTopics(
        IClaimIssuer _trustedIssuer,
        uint256[] calldata _newClaimTopics
    )
        external
        override
        onlyRole(REGISTRAR_ROLE)
    {
        address issuerAddress = address(_trustedIssuer);
        if (!_trustedIssuers[issuerAddress].exists) revert IssuerDoesNotExist(issuerAddress);
        if (_newClaimTopics.length == 0) revert NoClaimTopicsProvided();

        uint256[] storage currentClaimTopics = _trustedIssuers[issuerAddress].claimTopics;

        // --- Update Topic Lookups (Simple Iteration Approach) ---
        // 1. Remove issuer from all currently associated topic lookups
        for (uint256 i = 0; i < currentClaimTopics.length; i++) {
            // If state is consistent, this should always succeed as we are iterating over the issuer's current topics.
            // If it reverts due to inconsistency, that's an issue to investigate.
            _removeIssuerFromClaimTopic(currentClaimTopics[i], issuerAddress);
        }

        // 2. Add issuer to the lookup for all topics in the new list
        for (uint256 i = 0; i < _newClaimTopics.length; i++) {
            // Add the issuer to the topic list. The internal function handles appending.
            // Note: This doesn't prevent duplicates in the _issuersByClaimTopic list if the same topic
            // exists multiple times in _newClaimTopics, but retrieval functions will return duplicates harmlessly.
            // The primary _trustedIssuers mapping prevents duplicate *issuer* registration.
            _addIssuerToClaimTopic(_newClaimTopics[i], issuerAddress);
        }
        // --- End Update Topic Lookups ---

        // Update the stored claim topics list for the issuer
        _trustedIssuers[issuerAddress].claimTopics = _newClaimTopics;

        emit ClaimTopicsUpdated(issuerAddress, _newClaimTopics);
    }

    // --- View Functions ---

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function getTrustedIssuers() external view override returns (IClaimIssuer[] memory) {
        IClaimIssuer[] memory issuers = new IClaimIssuer[](_issuerAddresses.length);
        for (uint256 i = 0; i < _issuerAddresses.length; i++) {
            issuers[i] = IClaimIssuer(_issuerAddresses[i]);
        }
        return issuers;
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function getTrustedIssuerClaimTopics(IClaimIssuer _trustedIssuer)
        external
        view
        override
        returns (uint256[] memory)
    {
        if (!_trustedIssuers[address(_trustedIssuer)].exists) revert IssuerDoesNotExist(address(_trustedIssuer));
        return _trustedIssuers[address(_trustedIssuer)].claimTopics;
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    /// @notice Retrieves issuers trusted for a specific claim topic using the optimized lookup mapping.
    function getTrustedIssuersForClaimTopic(uint256 claimTopic)
        external
        view
        override
        returns (IClaimIssuer[] memory)
    {
        address[] storage issuerAddrs = _issuersByClaimTopic[claimTopic];
        IClaimIssuer[] memory issuers = new IClaimIssuer[](issuerAddrs.length);
        for (uint256 i = 0; i < issuerAddrs.length; i++) {
            issuers[i] = IClaimIssuer(issuerAddrs[i]);
        }
        return issuers;
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    /// @notice Checks if an issuer is trusted for a specific claim topic using the optimized index mapping.
    function hasClaimTopic(address _issuer, uint256 _claimTopic) external view override returns (bool) {
        // Index > 0 means the issuer exists in the list for that topic
        return _claimTopicIssuerIndex[_claimTopic][_issuer] > 0;
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    /// @notice Checks if an issuer address is registered as a trusted issuer.
    function isTrustedIssuer(address _issuer) external view override returns (bool) {
        return _trustedIssuers[_issuer].exists;
    }

    // --- Internal Helper Functions ---

    /// @dev Adds an issuer to the lookup array for a specific claim topic and updates the index mapping.
    function _addIssuerToClaimTopic(uint256 claimTopic, address issuerAddress) internal {
        address[] storage issuers = _issuersByClaimTopic[claimTopic];
        _claimTopicIssuerIndex[claimTopic][issuerAddress] = issuers.length + 1; // Store index+1
        issuers.push(issuerAddress);
    }

    /// @dev Removes an issuer from the lookup array for a specific claim topic using swap-and-pop and updates index
    /// mappings.
    function _removeIssuerFromClaimTopic(uint256 claimTopic, address issuerAddress) internal {
        uint256 indexToRemovePlusOne = _claimTopicIssuerIndex[claimTopic][issuerAddress];
        // Revert if index is 0 (issuer not found for this topic)
        if (indexToRemovePlusOne == 0) revert IssuerNotFoundInTopicList(issuerAddress, claimTopic);
        uint256 indexToRemove = indexToRemovePlusOne - 1; // Adjust to 0-based index

        address[] storage issuers = _issuersByClaimTopic[claimTopic];
        address lastIssuer = issuers[issuers.length - 1];

        // Only swap if the element to remove is not the last element
        if (issuerAddress != lastIssuer) {
            issuers[indexToRemove] = lastIssuer;
            _claimTopicIssuerIndex[claimTopic][lastIssuer] = indexToRemove + 1; // Update index of moved element (+1 for
                // storage)
        }

        // Delete the index mapping for the removed issuer and pop the last element
        delete _claimTopicIssuerIndex[claimTopic][issuerAddress];
        issuers.pop();
    }

    /// @dev Removes an address from a dynamic array using swap-and-pop (assumes address is present and unique).
    /// @dev This is used for the `_issuerAddresses` list which doesn't need an index mapping for removal.
    function _removeAddressFromList(address[] storage list, address addrToRemove) internal {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == addrToRemove) {
                // Replace the element to remove with the last element
                list[i] = list[list.length - 1];
                // Remove the last element
                list.pop();
                return; // Exit after removing the first occurrence
            }
        }
        // Should not happen if the issuer exists check passed before calling
        revert AddressNotFoundInList(addrToRemove);
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

    // --- Upgradeability (UUPS) ---

    /// @dev Authorizes an upgrade to a new implementation.
    ///      Requires the caller to have the `DEFAULT_ADMIN_ROLE`.
    function _authorizeUpgrade(address newImplementation)
        internal
        override(UUPSUpgradeable)
        onlyRole(DEFAULT_ADMIN_ROLE)
    { }
}
