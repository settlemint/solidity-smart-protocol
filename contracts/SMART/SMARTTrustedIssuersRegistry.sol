// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { IERC3643TrustedIssuersRegistry } from "../ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { IClaimIssuer } from "../onchainid/interface/IClaimIssuer.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { AccessControlDefaultAdminRulesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

// --- Errors ---
error InvalidIssuerAddress();
error NoClaimTopicsProvided();
error IssuerAlreadyExists(address issuerAddress);
error IssuerDoesNotExist(address issuerAddress);
error IssuerNotFoundInTopicList(address issuerAddress, uint256 claimTopic);
error AddressNotFoundInList(address addr);

/// @title SMARTTrustedIssuersRegistry
/// @notice Registry for trusted identity issuers, optimized for retrieving issuers by claim topic.
contract SMARTTrustedIssuersRegistry is
    Initializable,
    IERC3643TrustedIssuersRegistry,
    ERC2771ContextUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    UUPSUpgradeable
{
    // --- Roles ---
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    // --- Storage Variables ---
    struct TrustedIssuer {
        address issuer;
        uint256[] claimTopics;
        bool exists;
    }

    // Primary mapping storing details about each trusted issuer.
    mapping(address => TrustedIssuer) private _trustedIssuers;
    // List of all trusted issuer addresses, allowing iteration over all issuers.
    address[] private _issuerAddresses;

    // Mapping from claim topic to a list of issuer addresses authorized for that topic.
    // Used for efficient retrieval in getTrustedIssuersForClaimTopic.
    mapping(uint256 => address[]) private _issuersByClaimTopic;

    // Mapping from claim topic => issuer address => index in the _issuersByClaimTopic array.
    // Stores `index + 1` because the default mapping value is 0, allowing us to distinguish
    // between the first element (index 0) and non-existence.
    // Essential for efficient O(1) removal of an issuer from a topic's list using the swap-and-pop pattern
    // in the _removeIssuerFromClaimTopic helper function.
    mapping(uint256 => mapping(address => uint256)) private _claimTopicIssuerIndex;

    // --- Events ---
    event TrustedIssuerAdded(address indexed _issuer, uint256[] _claimTopics);
    event TrustedIssuerRemoved(address indexed _issuer);
    event ClaimTopicsUpdated(address indexed _issuer, uint256[] _claimTopics);

    // --- Constructor ---
    constructor() ERC2771ContextUpgradeable(address(0)) {
        _disableInitializers();
    }

    // --- Initializer ---
    function initialize(address initialAdmin) public initializer {
        __AccessControl_init();
        __AccessControlDefaultAdminRules_init(3 days, initialAdmin);
        __UUPSUpgradeable_init();

        _grantRole(REGISTRAR_ROLE, initialAdmin);
    }

    // --- State-Changing Functions ---
    function addTrustedIssuer(
        IClaimIssuer _trustedIssuer,
        uint256[] calldata _claimTopics
    )
        external
        onlyRole(REGISTRAR_ROLE)
    {
        address issuerAddress = address(_trustedIssuer);
        if (issuerAddress == address(0)) revert InvalidIssuerAddress();
        if (_claimTopics.length == 0) revert NoClaimTopicsProvided();
        if (_trustedIssuers[issuerAddress].exists) revert IssuerAlreadyExists(issuerAddress);

        _trustedIssuers[issuerAddress] = TrustedIssuer(issuerAddress, _claimTopics, true);
        _issuerAddresses.push(issuerAddress);

        // Add issuer to claim topic lookups
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            _addIssuerToClaimTopic(_claimTopics[i], issuerAddress);
        }

        emit TrustedIssuerAdded(issuerAddress, _claimTopics);
    }

    function removeTrustedIssuer(IClaimIssuer _trustedIssuer) external onlyRole(REGISTRAR_ROLE) {
        address issuerAddress = address(_trustedIssuer);
        if (!_trustedIssuers[issuerAddress].exists) revert IssuerDoesNotExist(issuerAddress);

        // Retrieve topics before deleting issuer data
        uint256[] memory topicsToRemove = _trustedIssuers[issuerAddress].claimTopics;

        // Remove from issuer address list
        _removeAddressFromList(_issuerAddresses, issuerAddress);

        // Remove from claim topic lookups
        for (uint256 i = 0; i < topicsToRemove.length; i++) {
            _removeIssuerFromClaimTopic(topicsToRemove[i], issuerAddress);
        }

        // Delete issuer data
        delete _trustedIssuers[issuerAddress];

        emit TrustedIssuerRemoved(issuerAddress);
    }

    function updateIssuerClaimTopics(
        IClaimIssuer _trustedIssuer,
        uint256[] calldata _newClaimTopics
    )
        external
        onlyRole(REGISTRAR_ROLE)
    {
        address issuerAddress = address(_trustedIssuer);
        if (!_trustedIssuers[issuerAddress].exists) revert IssuerDoesNotExist(issuerAddress);
        if (_newClaimTopics.length == 0) revert NoClaimTopicsProvided();

        uint256[] storage currentClaimTopics = _trustedIssuers[issuerAddress].claimTopics;
        uint256 currentLength = currentClaimTopics.length;
        uint256 newLength = _newClaimTopics.length;

        // Identify and remove topics that are in current but not in new
        for (uint256 i = 0; i < currentLength; i++) {
            uint256 topicToRemove = currentClaimTopics[i];
            bool foundInNew = false;
            for (uint256 j = 0; j < newLength; j++) {
                if (topicToRemove == _newClaimTopics[j]) {
                    foundInNew = true;
                    break;
                }
            }
            if (!foundInNew) {
                _removeIssuerFromClaimTopic(topicToRemove, issuerAddress);
            }
        }

        // Identify and add topics that are in new but not in current
        for (uint256 i = 0; i < newLength; i++) {
            uint256 topicToAdd = _newClaimTopics[i];
            bool foundInCurrent = false;
            for (uint256 j = 0; j < currentLength; j++) {
                if (topicToAdd == currentClaimTopics[j]) {
                    foundInCurrent = true;
                    break;
                }
            }
            if (!foundInCurrent) {
                _addIssuerToClaimTopic(topicToAdd, issuerAddress);
            }
        }

        // Update the stored claim topics
        _trustedIssuers[issuerAddress].claimTopics = _newClaimTopics;

        emit ClaimTopicsUpdated(issuerAddress, _newClaimTopics);
    }

    // --- View Functions ---
    function getTrustedIssuers() external view returns (IClaimIssuer[] memory) {
        IClaimIssuer[] memory issuers = new IClaimIssuer[](_issuerAddresses.length);
        for (uint256 i = 0; i < _issuerAddresses.length; i++) {
            issuers[i] = IClaimIssuer(_issuerAddresses[i]);
        }
        return issuers;
    }

    function getTrustedIssuerClaimTopics(IClaimIssuer _trustedIssuer) external view returns (uint256[] memory) {
        if (!_trustedIssuers[address(_trustedIssuer)].exists) revert IssuerDoesNotExist(address(_trustedIssuer));
        return _trustedIssuers[address(_trustedIssuer)].claimTopics;
    }

    /// @notice Retrieves issuers for a specific claim topic using the optimized lookup.
    function getTrustedIssuersForClaimTopic(uint256 claimTopic) external view returns (IClaimIssuer[] memory) {
        address[] storage issuerAddrs = _issuersByClaimTopic[claimTopic];
        IClaimIssuer[] memory issuers = new IClaimIssuer[](issuerAddrs.length);
        for (uint256 i = 0; i < issuerAddrs.length; i++) {
            issuers[i] = IClaimIssuer(issuerAddrs[i]);
        }
        return issuers;
    }

    function hasClaimTopic(address _issuer, uint256 _claimTopic) external view returns (bool) {
        // Check existence in the index mapping (index > 0 means present)
        return _claimTopicIssuerIndex[_claimTopic][_issuer] > 0;
    }

    function isTrustedIssuer(address _issuer) external view override returns (bool) {
        // Check existence in the primary mapping
        return _trustedIssuers[_issuer].exists;
    }

    // --- Internal Functions ---
    function _addIssuerToClaimTopic(uint256 claimTopic, address issuerAddress) internal {
        address[] storage issuers = _issuersByClaimTopic[claimTopic];
        // Store index + 1 because default mapping value is 0
        _claimTopicIssuerIndex[claimTopic][issuerAddress] = issuers.length + 1;
        issuers.push(issuerAddress);
    }

    function _removeIssuerFromClaimTopic(uint256 claimTopic, address issuerAddress) internal {
        uint256 indexToRemove = _claimTopicIssuerIndex[claimTopic][issuerAddress];
        if (indexToRemove == 0) revert IssuerNotFoundInTopicList(issuerAddress, claimTopic);
        indexToRemove -= 1; // Adjust back to 0-based index

        address[] storage issuers = _issuersByClaimTopic[claimTopic];
        address lastIssuer = issuers[issuers.length - 1];

        if (issuerAddress != lastIssuer) {
            // Move the last element to the removed element's slot
            issuers[indexToRemove] = lastIssuer;
            // Update the index mapping for the moved element (+1 for storage)
            _claimTopicIssuerIndex[claimTopic][lastIssuer] = indexToRemove + 1;
        }

        // Remove the index mapping for the removed issuer
        delete _claimTopicIssuerIndex[claimTopic][issuerAddress];
        // Remove the last element (which is either the one we removed or a duplicate)
        issuers.pop();
    }

    function _removeAddressFromList(address[] storage list, address addrToRemove) internal {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == addrToRemove) {
                address lastAddr = list[list.length - 1];
                // Replace the element to remove with the last element
                list[i] = lastAddr;
                // Remove the last element
                list.pop();
                return; // Assume address appears only once
            }
        }
        revert AddressNotFoundInList(addrToRemove);
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
    function _authorizeUpgrade(address newImplementation)
        internal
        override(UUPSUpgradeable)
        onlyRole(DEFAULT_ADMIN_ROLE)
    { }
}
