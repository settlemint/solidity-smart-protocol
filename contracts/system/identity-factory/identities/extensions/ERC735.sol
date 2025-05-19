// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { IERC735 } from "@onchainid/contracts/interface/IERC735.sol";
import { IClaimIssuer } from "@onchainid/contracts/interface/IClaimIssuer.sol"; // Required for addClaim's issuer
    // validation
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol"; // Required for IClaimIssuer interface

// --- Custom Errors ---
error IssuerCannotBeZeroAddress();
error ClaimNotValidAccordingToIssuer(address issuer, uint256 topic);
error ClaimDoesNotExist(bytes32 claimId);

/// @title ERC735 Claim Holder Standard Implementation
/// @dev Implementation of the IERC735 (Claim Holder) standard.
/// This contract manages claims issued by different entities.
contract ERC735 is IERC735 {
    struct Claim {
        uint256 topic;
        uint256 scheme;
        address issuer; // The issuer of the claim
        bytes signature; // Signature of (identity_address, topic, data)
        bytes data; // The data of the claim
        string uri; // The URI of the claim (e.g., IPFS hash)
    }

    mapping(bytes32 => Claim) internal _claims; // claimId => Claim
    mapping(uint256 => bytes32[]) internal _claimsByTopic; // topic => claimId[]

    /// @dev See {IERC735-addClaim}.
    /// Adds or updates a claim. Emits {ClaimAdded} or {ClaimChanged}.
    /// The `_signature` is `keccak256(abi.encode(address(this), _topic, _data))` signed by the `issuer`.
    /// Claim ID is `keccak256(abi.encode(_issuer, _topic))`.
    /// Requirements:
    /// - If `issuer` is not this contract, the claim must be verifiable via `IClaimIssuer(issuer).isClaimValid(...)`.
    /// - This function should typically be restricted (e.g., by a claim key in the inheriting contract).
    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address _issuer,
        bytes calldata _signature,
        bytes calldata _data,
        string calldata _uri
    )
        public
        virtual
        override
        returns (bytes32 claimId)
    {
        if (_issuer == address(0)) revert IssuerCannotBeZeroAddress();

        // If the issuer is an external contract, it should implement IClaimIssuer
        // to validate the claim. If issuer is self (this contract), it's a self-attested claim.
        if (_issuer != address(this)) {
            // The IClaimIssuer interface expects an IIdentity, so we cast address(this)
            // This implies that the contract inheriting ERC735 might also need to implement IIdentity or parts of it
            // for external issuers to validate claims against it correctly.
            if (!IClaimIssuer(_issuer).isClaimValid(IIdentity(payable(address(this))), _topic, _signature, _data)) {
                revert ClaimNotValidAccordingToIssuer({ issuer: _issuer, topic: _topic });
            }
        }

        claimId = keccak256(abi.encodePacked(_issuer, _topic));

        bool isNewClaim = _claims[claimId].issuer == address(0);

        _claims[claimId].topic = _topic;
        _claims[claimId].scheme = _scheme;
        _claims[claimId].issuer = _issuer; // Set issuer after potential validation
        _claims[claimId].signature = _signature;
        _claims[claimId].data = _data;
        _claims[claimId].uri = _uri;

        if (isNewClaim) {
            _claimsByTopic[_topic].push(claimId);
            emit ClaimAdded(claimId, _topic, _scheme, _issuer, _signature, _data, _uri);
        } else {
            // Ensure the issuer is not changing for an existing claimId, as claimId is derived from issuer and topic.
            // The EIP735 spec implies `addClaim` can update, so if issuer must be constant for a claimId,
            // this means only other fields (scheme, signature, data, uri) can change.
            // The reference Identity.sol allows changing the claim if claimId exists.
            emit ClaimChanged(claimId, _topic, _scheme, _issuer, _signature, _data, _uri);
        }

        return claimId;
    }

    /// @dev See {IERC735-removeClaim}.
    /// Removes a claim by its ID. Emits {ClaimRemoved}.
    /// Claim ID is `keccak256(abi.encode(issuer_address, topic))`.
    /// Requirements:
    /// - The `_claimId` must correspond to an existing claim.
    /// - This function should typically be restricted (e.g., by a claim key or management key in the inheriting
    /// contract,
    ///   or only allow issuer or self to remove).
    function removeClaim(bytes32 _claimId) public virtual override returns (bool success) {
        Claim storage claimToRemove = _claims[_claimId];
        if (claimToRemove.issuer == address(0)) revert ClaimDoesNotExist({ claimId: _claimId }); // Check if claim
            // exists

        uint256 topic = claimToRemove.topic;

        // Remove from _claimsByTopic array
        bytes32[] storage claimsForTopic = _claimsByTopic[topic];
        uint256 claimIndex = type(uint256).max;
        uint256 claimsForTopicLength = claimsForTopic.length;
        for (uint256 i = 0; i < claimsForTopicLength; ++i) {
            if (claimsForTopic[i] == _claimId) {
                claimIndex = i;
                break;
            }
        }

        // This should ideally always find the claim if it exists in _claims
        if (claimIndex != type(uint256).max) {
            claimsForTopic[claimIndex] = claimsForTopic[claimsForTopicLength - 1];
            claimsForTopic.pop();
        }

        emit ClaimRemoved(
            _claimId,
            claimToRemove.topic,
            claimToRemove.scheme,
            claimToRemove.issuer,
            claimToRemove.signature,
            claimToRemove.data,
            claimToRemove.uri
        );

        delete _claims[_claimId];
        return true;
    }

    /// @dev See {IERC735-getClaim}.
    /// Retrieves a claim by its ID.
    /// Claim ID is `keccak256(abi.encode(issuer_address, topic))`.
    function getClaim(bytes32 _claimId)
        external
        view
        virtual
        override
        returns (
            uint256 topic,
            uint256 scheme,
            address issuer,
            bytes memory signature,
            bytes memory data,
            string memory uri
        )
    {
        Claim storage c = _claims[_claimId];
        // No explicit require for existence, will return zero values if not found, as per EIP.
        return (c.topic, c.scheme, c.issuer, c.signature, c.data, c.uri);
    }

    /// @dev See {IERC735-getClaimIdsByTopic}.
    /// Returns an array of claim IDs associated with a specific topic.
    function getClaimIdsByTopic(uint256 _topic) external view virtual override returns (bytes32[] memory claimIds) {
        return _claimsByTopic[_topic];
    }
}
