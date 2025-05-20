// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { ISMARTIdentity } from "./ISMARTIdentity.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
import { IERC735 } from "@onchainid/contracts/interface/IERC735.sol";
import { IERC734 } from "@onchainid/contracts/interface/IERC734.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

// Import local extensions
import { ERC734 } from "./extensions/ERC734.sol";
import { ERC735 } from "./extensions/ERC735.sol";

// --- Custom Errors for SMARTIdentityImplementation ---
error AlreadyInitialized();
error InvalidInitialManagementKey();
error SenderLacksManagementKey();
error SenderLacksActionKey();
error SenderLacksClaimSignerKey();
// Errors for checks that might be redundant if ERC734.sol handles them robustly
error ReplicatedExecutionIdDoesNotExist(uint256 executionId);
error ReplicatedExecutionAlreadyPerformed(uint256 executionId);

/// @title SMART Identity Implementation Contract (Logic for Wallet Identities)
/// @author SettleMint Tokenization Services
/// @notice This contract provides the upgradeable logic for standard on-chain identities associated with user wallets
///         within the SMART Protocol. It implements `IIdentity` using local `ERC734` and `ERC735` extensions.
/// @dev This contract is intended to be deployed once and then used as the logic implementation target for multiple
///      `SMARTIdentityProxy` contracts. It inherits `ERC734` for key management, `ERC735` for claim management,
///      `ERC165Upgradeable` for interface detection, and `ERC2771ContextUpgradeable` for meta-transactions.
contract SMARTIdentityImplementation is ISMARTIdentity, ERC734, ERC735, ERC165Upgradeable, ERC2771ContextUpgradeable {
    // --- State Variables ---
    bool private _smartIdentityInitialized;

    // --- Constants for Key Purposes ---
    uint256 public constant MANAGEMENT_KEY_PURPOSE = 1;
    uint256 public constant ACTION_KEY_PURPOSE = 2;
    uint256 public constant CLAIM_SIGNER_KEY_PURPOSE = 3;
    uint256 public constant ENCRYPTION_KEY_PURPOSE = 4; // Optional, but common

    // --- Modifiers for Access Control ---
    modifier onlyManager() {
        if (
            !(
                _msgSender() == address(this)
                    || keyHasPurpose(keccak256(abi.encode(_msgSender())), MANAGEMENT_KEY_PURPOSE)
            )
        ) {
            revert SenderLacksManagementKey();
        }
        _;
    }

    modifier onlyClaimKey() {
        if (
            !(
                _msgSender() == address(this)
                    || keyHasPurpose(keccak256(abi.encode(_msgSender())), CLAIM_SIGNER_KEY_PURPOSE)
            )
        ) {
            revert SenderLacksClaimSignerKey();
        }
        _;
    }

    /// @notice Constructor for the `SMARTIdentityImplementation`.
    /// @dev Initializes ERC2771 context with the provided forwarder.
    ///      The main identity initialization (setting the first management key) is done via `initializeSMARTIdentity`.
    constructor(address forwarder) ERC2771ContextUpgradeable(forwarder) {
        _disableInitializers();
    }

    /**
     * @notice Initializes the SMARTIdentityImplementation state.
     * @dev This function is intended to be called only once by a proxy contract via delegatecall.
     *      It sets the initial management key for this identity and initializes ERC165 support.
     *      This replaces the old `__Identity_init` call.
     * @param initialManagementKey The address to be set as the initial management key for this identity.
     */
    function initialize(address initialManagementKey) external override initializer {
        if (_smartIdentityInitialized) revert AlreadyInitialized();
        _smartIdentityInitialized = true;

        if (initialManagementKey == address(0)) revert InvalidInitialManagementKey();

        __ERC165_init_unchained(); // Initialize ERC165 storage

        bytes32 keyHash = keccak256(abi.encode(initialManagementKey));

        // Directly set up the first management key using storage from ERC734
        // This mimics the behavior of OnchainID's __Identity_init
        _keys[keyHash].key = keyHash;
        _keys[keyHash].purposes = [MANAGEMENT_KEY_PURPOSE]; // Initialize dynamic array with one element
        _keys[keyHash].keyType = 1; // Assuming KeyType 1 for ECDSA / standard Ethereum address key

        _keysByPurpose[MANAGEMENT_KEY_PURPOSE].push(keyHash);

        // Emit event defined in ERC734/IERC734
        emit KeyAdded(keyHash, MANAGEMENT_KEY_PURPOSE, 1);
    }

    // --- ERC734 (Key Holder) Functions - Overridden for Access Control & Specific Logic ---

    /// @inheritdoc IERC734
    /// @dev Adds a key with a specific purpose and type. Requires MANAGEMENT_KEY purpose.
    function addKey(
        bytes32 _key,
        uint256 _purpose,
        uint256 _keyType
    )
        public
        virtual
        override(ERC734, IERC734) // Overrides ERC734's implementation and fulfills IERC734
        onlyManager
        returns (bool success)
    {
        return super.addKey(_key, _purpose, _keyType);
    }

    /// @inheritdoc IERC734
    /// @dev Removes a purpose from a key. If it's the last purpose, the key is removed. Requires MANAGEMENT_KEY
    /// purpose.
    function removeKey(
        bytes32 _key,
        uint256 _purpose
    )
        public
        virtual
        override(ERC734, IERC734)
        onlyManager
        returns (bool success)
    {
        return super.removeKey(_key, _purpose);
    }

    /// @inheritdoc IERC734
    /// @dev Approves or disapproves an execution.
    ///      Requires MANAGEMENT_KEY if the execution targets the identity itself.
    ///      Requires ACTION_KEY if the execution targets an external contract.
    function approve(uint256 _id, bool _toApprove) public virtual override(ERC734, IERC734) returns (bool success) {
        Execution storage executionToApprove = _executions[_id];
        if (_id >= _executionNonce) revert ReplicatedExecutionIdDoesNotExist({ executionId: _id });
        if (executionToApprove.executed) revert ReplicatedExecutionAlreadyPerformed({ executionId: _id });

        bytes32 senderKeyHash = keccak256(abi.encode(_msgSender()));
        if (executionToApprove.to == address(this)) {
            if (!keyHasPurpose(senderKeyHash, MANAGEMENT_KEY_PURPOSE)) {
                revert SenderLacksManagementKey();
            }
        } else {
            if (!keyHasPurpose(senderKeyHash, ACTION_KEY_PURPOSE)) {
                revert SenderLacksActionKey();
            }
        }
        return super.approve(_id, _toApprove);
    }

    /// @inheritdoc IERC734
    /// @dev Initiates an execution. If the sender has MANAGEMENT_KEY, or ACTION_KEY (for external calls),
    ///      the execution is auto-approved.
    function execute(
        address _to,
        uint256 _value,
        bytes calldata _data
    )
        public
        payable
        virtual
        override(ERC734, IERC734)
        returns (uint256 executionId)
    {
        executionId = super.execute(_to, _value, _data);

        bytes32 senderKeyHash = keccak256(abi.encode(_msgSender()));
        bool autoApproved = false;

        if (keyHasPurpose(senderKeyHash, MANAGEMENT_KEY_PURPOSE)) {
            autoApproved = true;
        } else if (_to != address(this) && keyHasPurpose(senderKeyHash, ACTION_KEY_PURPOSE)) {
            autoApproved = true;
        }

        if (autoApproved) {
            this.approve(executionId, true);
        }

        return executionId;
    }

    // Inherited view functions from ERC734:
    // getKey(bytes32) external view returns (uint256[] memory purposes, uint256 keyType, bytes32 key)
    // getKeyPurposes(bytes32) external view returns (uint256[] memory purposes)
    // getKeysByPurpose(uint256) external view returns (bytes32[] memory keys)
    // keyHasPurpose(bytes32, uint256) external view returns (bool exists)

    // --- ERC735 (Claim Holder) Functions - Overridden for Access Control ---

    /// @inheritdoc IERC735
    /// @dev Adds or updates a claim. Requires CLAIM_SIGNER_KEY purpose from the sender.
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
        override(ERC735, IERC735) // Overrides ERC735's implementation and fulfills IERC735
        onlyClaimKey
        returns (bytes32 claimId)
    {
        return super.addClaim(_topic, _scheme, _issuer, _signature, _data, _uri);
    }

    /// @inheritdoc IERC735
    /// @dev Removes a claim. Requires CLAIM_SIGNER_KEY purpose from the sender.
    function removeClaim(bytes32 _claimId)
        public
        virtual
        override(ERC735, IERC735)
        onlyClaimKey
        returns (bool success)
    {
        return super.removeClaim(_claimId);
    }

    // Inherited view functions from ERC735:
    // getClaim(bytes32) external view returns (uint256 topic, uint256 scheme, address issuer, bytes memory signature,
    // bytes memory data, string memory uri)
    // getClaimIdsByTopic(uint256) external view returns (bytes32[] memory claimIds)

    // --- IIdentity Specific Functions ---

    /// @inheritdoc IIdentity
    /// @dev Checks if a claim is valid. For self-issued claims (issuer is this identity),
    ///      it verifies the signature against a CLAIM_SIGNER_KEY registered on this identity.
    ///      This implementation is adapted from OnchainID's Identity.sol.
    function isClaimValid(
        IIdentity _identity, // The identity holder contract related to the claim
        uint256 claimTopic,
        bytes calldata sig,
        bytes calldata data
    )
        external // As per IIdentity interface
        view
        virtual
        override // Implements IIdentity.isClaimValid (no other base contract to specify here)
        returns (bool claimValid)
    {
        bytes32 dataHash = keccak256(abi.encode(_identity, claimTopic, data));
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
        address recoveredSigner = getRecoveredAddress(sig, prefixedHash);
        if (recoveredSigner == address(0)) {
            return false; // Invalid signature or recovery failed
        }
        bytes32 hashedSignerAddress = keccak256(abi.encode(recoveredSigner));
        return keyHasPurpose(hashedSignerAddress, CLAIM_SIGNER_KEY_PURPOSE);
    }

    /// @dev Recovers the address that signed the given data hash.
    ///      Copied from OnchainID's Identity.sol for use in `isClaimValid`.
    /// @param sig The signature bytes (65 bytes: r, s, v).
    /// @param dataHash The keccak256 hash of the data that was signed (usually a prefixed hash).
    /// @return addr The recovered Ethereum address, or address(0) if recovery fails.
    function getRecoveredAddress(bytes memory sig, bytes32 dataHash) public pure returns (address addr) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Check the signature length
        if (sig.length != 65) {
            return address(0);
        }

        // Divide the signature in r, s and v variables
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        // Adjust v if it's 0 or 1 (legacy EIP-155 handling not strictly needed for >=27)
        if (v < 27) {
            v += 27;
        }

        // Ensure v is either 27 or 28
        if (v != 27 && v != 28) {
            return address(0);
        }

        return ecrecover(dataHash, v, r, s);
    }

    // --- ERC165 Support ---

    /// @inheritdoc IERC165
    /// @notice Checks if the contract supports a given interface ID.
    /// @dev It declares support for `IIdentity`, `IERC734`, `IERC735` (components of `IIdentity`),
    ///      and `IERC165` itself. It chains to `ERC165Upgradeable.supportsInterface`.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Upgradeable) // Overrides the one from ERC165Upgradeable
        returns (bool)
    {
        return interfaceId == type(ISMARTIdentity).interfaceId || interfaceId == type(IERC734).interfaceId
            || interfaceId == type(IERC735).interfaceId || interfaceId == type(IIdentity).interfaceId
            || super.supportsInterface(interfaceId);
    }

    // _msgSender() is inherited from ERC2771ContextUpgradeable and should be used for access control.
}
