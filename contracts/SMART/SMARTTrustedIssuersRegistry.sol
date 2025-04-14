// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { IERC3643TrustedIssuersRegistry } from "../ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title SMARTTrustedIssuersRegistry
/// @notice Registry for trusted identity issuers
contract SMARTTrustedIssuersRegistry is IERC3643TrustedIssuersRegistry, Ownable {
    /// Storage
    struct TrustedIssuer {
        address issuer;
        uint256[] claimTopics;
        bool exists;
    }

    mapping(address => TrustedIssuer) private _trustedIssuers;
    address[] private _issuers;

    /// Events
    event TrustedIssuerAdded(address indexed issuer, uint256[] claimTopics);
    event TrustedIssuerRemoved(address indexed issuer);
    event ClaimTopicsUpdated(address indexed issuer, uint256[] claimTopics);

    constructor() Ownable(msg.sender) { }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function addTrustedIssuer(address _issuer, uint256[] calldata _claimTopics) external override onlyOwner {
        require(_issuer != address(0), "Invalid issuer address");
        require(!_trustedIssuers[_issuer].exists, "Issuer already exists");
        require(_claimTopics.length > 0, "No claim topics provided");

        _trustedIssuers[_issuer] = TrustedIssuer(_issuer, _claimTopics, true);
        _issuers.push(_issuer);

        emit TrustedIssuerAdded(_issuer, _claimTopics);
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function removeTrustedIssuer(address _issuer) external override onlyOwner {
        require(_trustedIssuers[_issuer].exists, "Issuer does not exist");

        delete _trustedIssuers[_issuer];
        for (uint256 i = 0; i < _issuers.length; i++) {
            if (_issuers[i] == _issuer) {
                _issuers[i] = _issuers[_issuers.length - 1];
                _issuers.pop();
                break;
            }
        }

        emit TrustedIssuerRemoved(_issuer);
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function updateIssuerClaimTopics(address _issuer, uint256[] calldata _claimTopics) external override onlyOwner {
        require(_trustedIssuers[_issuer].exists, "Issuer does not exist");
        require(_claimTopics.length > 0, "No claim topics provided");

        _trustedIssuers[_issuer].claimTopics = _claimTopics;

        emit ClaimTopicsUpdated(_issuer, _claimTopics);
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function getTrustedIssuers() external view override returns (address[] memory) {
        return _issuers;
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function isTrustedIssuer(address _issuer) external view override returns (bool) {
        return _trustedIssuers[_issuer].exists;
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function getTrustedIssuerClaimTopics(address _issuer) external view override returns (uint256[] memory) {
        require(_trustedIssuers[_issuer].exists, "Issuer does not exist");
        return _trustedIssuers[_issuer].claimTopics;
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function hasClaimTopic(address _issuer, uint256 _claimTopic) external view override returns (bool) {
        if (!_trustedIssuers[_issuer].exists) return false;

        uint256[] memory claimTopics = _trustedIssuers[_issuer].claimTopics;
        for (uint256 i = 0; i < claimTopics.length; i++) {
            if (claimTopics[i] == _claimTopic) {
                return true;
            }
        }
        return false;
    }
}
