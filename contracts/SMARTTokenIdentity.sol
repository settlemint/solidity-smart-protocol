// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { ERC2771Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
import { IClaimIssuer } from "@onchainid/contracts/interface/IClaimIssuer.sol";
import { Version } from "@onchainid/contracts/version/Version.sol";
import { Storage } from "@onchainid/contracts/storage/Storage.sol";
import { SMARTTokenAccessControlManaged } from "./access-control-manager/SMARTTokenAccessControlManaged.sol";
import { ISMARTTokenAccessControlManager } from
    "./access-control-manager/interfaces/ISMARTTokenAccessControlManager.sol";
import { SMARTExtensionAccessControlAuthorization } from
    "./extensions/common/SMARTExtensionAccessControlAuthorization.sol";
/**
 * @title SMART Token Identity Contract (Abstract)
 * @notice A streamlined identity contract for token systems that relies solely on role-based access control
 * @dev Implements IIdentity interface but without key-based access control.
 *      All permissions are managed through the SMARTTokenAccessControlManager.
 *      Key-based functions throw "Unsupported" errors as they are not compatible
 *      with this token-specific implementation.
 */

contract SMARTTokenIdentity is Storage, IIdentity, Version, SMARTTokenAccessControlManaged, ERC2771Context {
    // --- Events ---
    // Keep events from IIdentity for compatibility

    // --- Errors ---

    /// @dev Error thrown when attempting to use key-based functionality
    error UnsupportedKeyOperation();

    /// @dev Error thrown when attempting to use execution functionality in an unsupported way
    error UnsupportedExecutionOperation();

    /// @dev Error when trying to interact with the implementation contract directly
    error LibraryInteractionForbidden();

    /**
     * @notice Prevent any direct calls to the implementation contract (marked by _canInteract = false).
     */
    modifier delegatedOnly() {
        if (_canInteract != true) {
            revert LibraryInteractionForbidden();
        }
        _;
    }

    /**
     * @notice Constructor for the SMARTTokenIdentity.
     * @param manager The address of the deployed SMARTTokenAccessControlManager contract that governs permissions
     */
    constructor(
        address manager,
        address forwarder
    )
        Version()
        SMARTTokenAccessControlManaged(manager)
        ERC2771Context(forwarder)
    {
        // Setup the contract for immediate use
        _initialized = true;
        _canInteract = true;
    }

    // --- Unsupported Key Management Functions ---

    /**
     * @notice Adding keys is not supported in this token-specific implementation.
     * @dev Always reverts with UnsupportedKeyOperation.
     */
    function addKey(bytes32, uint256, uint256) public pure override returns (bool) {
        revert UnsupportedKeyOperation();
    }

    /**
     * @notice Removing keys is not supported in this token-specific implementation.
     * @dev Always reverts with UnsupportedKeyOperation.
     */
    function removeKey(bytes32, uint256) public pure override returns (bool) {
        revert UnsupportedKeyOperation();
    }

    // --- Execution Functions ---

    /**
     * @notice Executes an action through the identity contract.
     * @dev Checks authorization via the access control manager rather than keys.
     * @param _to The destination address for the execution
     * @param _value The amount of ETH to send
     * @param _data The call data to send
     * @return executionId The ID of the requested execution
     */
    function execute(
        address _to,
        uint256 _value,
        bytes memory _data
    )
        external
        payable
        override
        delegatedOnly
        returns (uint256 executionId)
    {
        // Check permission via the access manager
        _accessManager.authorizeIdentityExecution(_msgSender());

        // Register the execution
        executionId = _executionNonce;
        _executions[executionId].to = _to;
        _executions[executionId].value = _value;
        _executions[executionId].data = _data;
        _executionNonce++;

        emit ExecutionRequested(executionId, _to, _value, _data);

        // Execute immediately
        _executions[executionId].approved = true;

        bool success;
        (success,) = _to.call{ value: _value }(_data);

        if (success) {
            _executions[executionId].executed = true;
            emit Executed(executionId, _to, _value, _data);
        } else {
            emit ExecutionFailed(executionId, _to, _value, _data);
        }

        return executionId;
    }

    /**
     * @notice Approving executions is not supported in this token-specific implementation.
     * @dev Always reverts with UnsupportedExecutionOperation.
     */
    function approve(uint256, bool) public pure override returns (bool) {
        revert UnsupportedExecutionOperation();
    }

    // --- Claim Management Functions ---

    /**
     * @notice Adds a claim to the identity.
     * @dev Authorization is checked via the access control manager.
     * @param _topic The type of claim
     * @param _scheme The scheme with which this claim should be verified
     * @param _issuer The issuer of the claim
     * @param _signature The signature of the claim
     * @param _data The claim data
     * @param _uri The URI of the claim
     * @return claimRequestId The ID of the added claim
     */
    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address _issuer,
        bytes memory _signature,
        bytes memory _data,
        string memory _uri
    )
        public
        override
        delegatedOnly
        returns (bytes32 claimRequestId)
    {
        // Check permission via the access manager
        _accessManager.authorizeManageIdentityClaims(_msgSender());

        // Standard claim validation if issuer is not self
        if (_issuer != address(this)) {
            require(
                IClaimIssuer(_issuer).isClaimValid(IIdentity(address(this)), _topic, _signature, _data), "Invalid claim"
            );
        }

        // Store the claim
        claimRequestId = keccak256(abi.encode(_issuer, _topic));
        _claims[claimRequestId].topic = _topic;
        _claims[claimRequestId].scheme = _scheme;
        _claims[claimRequestId].signature = _signature;
        _claims[claimRequestId].data = _data;
        _claims[claimRequestId].uri = _uri;

        if (_claims[claimRequestId].issuer != _issuer) {
            _claimsByTopic[_topic].push(claimRequestId);
            _claims[claimRequestId].issuer = _issuer;

            emit ClaimAdded(claimRequestId, _topic, _scheme, _issuer, _signature, _data, _uri);
        } else {
            emit ClaimChanged(claimRequestId, _topic, _scheme, _issuer, _signature, _data, _uri);
        }

        return claimRequestId;
    }

    /**
     * @notice Removes a claim from the identity.
     * @dev Authorization is checked via the access control manager.
     * @param _claimId The ID of the claim to remove
     * @return success Boolean indicating success
     */
    function removeClaim(bytes32 _claimId) public override delegatedOnly returns (bool success) {
        // Check permission via the access manager
        _accessManager.authorizeManageIdentityClaims(_msgSender());

        uint256 _topic = _claims[_claimId].topic;
        if (_topic == 0) {
            revert("NonExisting: There is no claim with this ID");
        }

        // Remove claim from topic mapping
        uint256 claimIndex = 0;
        uint256 arrayLength = _claimsByTopic[_topic].length;
        while (_claimsByTopic[_topic][claimIndex] != _claimId) {
            claimIndex++;

            if (claimIndex >= arrayLength) {
                break;
            }
        }

        _claimsByTopic[_topic][claimIndex] = _claimsByTopic[_topic][arrayLength - 1];
        _claimsByTopic[_topic].pop();

        emit ClaimRemoved(
            _claimId,
            _topic,
            _claims[_claimId].scheme,
            _claims[_claimId].issuer,
            _claims[_claimId].signature,
            _claims[_claimId].data,
            _claims[_claimId].uri
        );

        delete _claims[_claimId];

        return true;
    }

    // --- View Functions (Compatible with IIdentity) ---

    /**
     * @notice Gets data about a claim.
     * @param _claimId The ID of the claim
     * @return topic The topic of the claim
     * @return scheme The scheme of the claim
     * @return issuer The issuer of the claim
     * @return signature The signature of the claim
     * @return data The data of the claim
     * @return uri The URI of the claim
     */
    function getClaim(bytes32 _claimId)
        public
        view
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
        return (
            _claims[_claimId].topic,
            _claims[_claimId].scheme,
            _claims[_claimId].issuer,
            _claims[_claimId].signature,
            _claims[_claimId].data,
            _claims[_claimId].uri
        );
    }

    /**
     * @notice Gets claim IDs by topic.
     * @param _topic The topic to get claims for
     * @return claimIds The array of claim IDs
     */
    function getClaimIdsByTopic(uint256 _topic) external view override returns (bytes32[] memory claimIds) {
        return _claimsByTopic[_topic];
    }

    /**
     * @notice Gets key data.
     * @dev Returns empty/minimal data for most keys as they're not used for access control.
     * @param _key The key to get data for
     * @return purposes The purposes of the key
     * @return keyType The type of the key
     * @return key The key data
     */
    function getKey(bytes32 _key)
        external
        view
        override
        returns (uint256[] memory purposes, uint256 keyType, bytes32 key)
    {
        return (_keys[_key].purposes, _keys[_key].keyType, _keys[_key].key);
    }

    /**
     * @notice Gets the purposes of a key.
     * @param _key The key to get purposes for
     * @return _purposes The purposes of the key
     */
    function getKeyPurposes(bytes32 _key) external view override returns (uint256[] memory _purposes) {
        return (_keys[_key].purposes);
    }

    /**
     * @notice Gets keys by purpose.
     * @param _purpose The purpose to get keys for
     * @return keys The array of keys
     */
    function getKeysByPurpose(uint256 _purpose) external view override returns (bytes32[] memory keys) {
        return _keysByPurpose[_purpose];
    }

    /**
     * @notice Checks if a key has a purpose.
     * @dev For compatibility only - not used for access control.
     * @param _key The key to check
     * @param _purpose The purpose to check for
     * @return result True if the key has the purpose
     */
    function keyHasPurpose(bytes32 _key, uint256 _purpose) public view override returns (bool result) {
        Key memory key = _keys[_key];
        if (key.key == 0) return false;

        for (uint256 i = 0; i < key.purposes.length; i++) {
            if (key.purposes[i] == 1 || key.purposes[i] == _purpose) return true;
        }

        return false;
    }

    /**
     * @notice Checks if a claim is valid.
     * @dev For compatibility with IClaimIssuer - basic implementation.
     * @param _identity The identity to check the claim for
     * @param claimTopic The topic of the claim
     * @param sig The signature of the claim
     * @param data The data of the claim
     * @return claimValid True if the claim is valid
     */
    function isClaimValid(
        IIdentity _identity,
        uint256 claimTopic,
        bytes memory sig,
        bytes memory data
    )
        public
        view
        virtual
        override
        returns (bool claimValid)
    {
        bytes32 dataHash = keccak256(abi.encode(_identity, claimTopic, data));
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));

        address recovered = getRecoveredAddress(sig, prefixedHash);
        bytes32 hashedAddr = keccak256(abi.encode(recovered));

        // Simplified check that relies on the initial key setup
        if (keyHasPurpose(hashedAddr, 3)) {
            return true;
        }

        return false;
    }

    /**
     * @notice Gets the recovered address from a signature.
     * @param sig The signature
     * @param dataHash The data hash
     * @return addr The recovered address
     */
    function getRecoveredAddress(bytes memory sig, bytes32 dataHash) public pure returns (address addr) {
        bytes32 ra;
        bytes32 sa;
        uint8 va;

        if (sig.length != 65) {
            return address(0);
        }

        assembly {
            ra := mload(add(sig, 32))
            sa := mload(add(sig, 64))
            va := byte(0, mload(add(sig, 96)))
        }

        if (va < 27) {
            va += 27;
        }

        address recoveredAddress = ecrecover(dataHash, va, ra, sa);
        return recoveredAddress;
    }

    /**
     * @notice Checks if an account has a specific role, delegating the check to the access manager.
     * @param role The role identifier
     * @param account The address to check
     * @return True if the account has the role
     */
    function hasRole(
        bytes32 role,
        address account
    )
        public
        view
        virtual
        override(SMARTTokenAccessControlManaged)
        returns (bool)
    {
        return _accessManager.hasRole(role, account);
    }

    /// @dev Resolves msgSender across Context and ERC2771Context.
    function _msgSender()
        internal
        view
        virtual
        override(ERC2771Context, SMARTExtensionAccessControlAuthorization)
        returns (address)
    {
        return ERC2771Context._msgSender();
    }
}
