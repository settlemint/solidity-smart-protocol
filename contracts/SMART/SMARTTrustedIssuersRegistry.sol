// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { IERC3643TrustedIssuersRegistry } from "../ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IClaimIssuer } from "../onchainid/interface/IClaimIssuer.sol";

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
    mapping(uint256 => IClaimIssuer[]) private _issuersByClaimTopic;

    /// Events
    event TrustedIssuerAdded(address indexed _issuer, uint256[] _claimTopics);
    event TrustedIssuerRemoved(address indexed _issuer);
    event ClaimTopicsUpdated(address indexed _issuer, uint256[] _claimTopics);

    constructor() Ownable(msg.sender) { }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function addTrustedIssuer(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external onlyOwner {
        require(address(_trustedIssuer) != address(0), "Invalid issuer address");
        require(_claimTopics.length > 0, "No claim topics provided");
        require(!_trustedIssuers[address(_trustedIssuer)].exists, "Issuer already exists");

        _trustedIssuers[address(_trustedIssuer)] = TrustedIssuer(address(_trustedIssuer), _claimTopics, true);
        _issuers.push(address(_trustedIssuer));

        // Add issuer to claim topics mapping
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            _issuersByClaimTopic[_claimTopics[i]].push(_trustedIssuer);
        }

        emit TrustedIssuerAdded(address(_trustedIssuer), _claimTopics);
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function removeTrustedIssuer(IClaimIssuer _trustedIssuer) external onlyOwner {
        require(_trustedIssuers[address(_trustedIssuer)].exists, "Issuer does not exist");

        // Remove issuer from claim topics mapping
        uint256[] memory claimTopics = _trustedIssuers[address(_trustedIssuer)].claimTopics;
        for (uint256 i = 0; i < claimTopics.length; i++) {
            IClaimIssuer[] storage issuers = _issuersByClaimTopic[claimTopics[i]];
            for (uint256 j = 0; j < issuers.length; j++) {
                if (issuers[j] == _trustedIssuer) {
                    issuers[j] = issuers[issuers.length - 1];
                    issuers.pop();
                    break;
                }
            }
        }

        delete _trustedIssuers[address(_trustedIssuer)];
        for (uint256 i = 0; i < _issuers.length; i++) {
            if (_issuers[i] == address(_trustedIssuer)) {
                _issuers[i] = _issuers[_issuers.length - 1];
                _issuers.pop();
                break;
            }
        }

        emit TrustedIssuerRemoved(address(_trustedIssuer));
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function updateIssuerClaimTopics(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external onlyOwner {
        require(_trustedIssuers[address(_trustedIssuer)].exists, "Issuer does not exist");
        require(_claimTopics.length > 0, "No claim topics provided");

        // Remove issuer from old claim topics
        uint256[] memory oldClaimTopics = _trustedIssuers[address(_trustedIssuer)].claimTopics;
        for (uint256 i = 0; i < oldClaimTopics.length; i++) {
            IClaimIssuer[] storage issuers = _issuersByClaimTopic[oldClaimTopics[i]];
            for (uint256 j = 0; j < issuers.length; j++) {
                if (issuers[j] == _trustedIssuer) {
                    issuers[j] = issuers[issuers.length - 1];
                    issuers.pop();
                    break;
                }
            }
        }

        // Add issuer to new claim topics
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            _issuersByClaimTopic[_claimTopics[i]].push(_trustedIssuer);
        }

        _trustedIssuers[address(_trustedIssuer)].claimTopics = _claimTopics;

        emit ClaimTopicsUpdated(address(_trustedIssuer), _claimTopics);
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function getTrustedIssuers() external view returns (IClaimIssuer[] memory) {
        IClaimIssuer[] memory issuers = new IClaimIssuer[](_issuers.length);
        for (uint256 i = 0; i < _issuers.length; i++) {
            issuers[i] = IClaimIssuer(_issuers[i]);
        }
        return issuers;
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function getTrustedIssuerClaimTopics(IClaimIssuer _trustedIssuer) external view returns (uint256[] memory) {
        require(_trustedIssuers[address(_trustedIssuer)].exists, "Issuer does not exist");
        return _trustedIssuers[address(_trustedIssuer)].claimTopics;
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function getTrustedIssuersForClaimTopic(uint256 claimTopic) external view returns (IClaimIssuer[] memory) {
        return _issuersByClaimTopic[claimTopic];
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function hasClaimTopic(address _issuer, uint256 _claimTopic) external view returns (bool) {
        if (!_trustedIssuers[_issuer].exists) return false;

        uint256[] memory claimTopics = _trustedIssuers[_issuer].claimTopics;
        for (uint256 i = 0; i < claimTopics.length; i++) {
            if (claimTopics[i] == _claimTopic) {
                return true;
            }
        }
        return false;
    }

    function isTrustedIssuer(address _issuer) external view override returns (bool) {
        TrustedIssuer storage issuer = _trustedIssuers[_issuer];
        return issuer.claimTopics.length > 0;
    }
}
