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
import { OnChainIdentity } from "./extensions/OnChainIdentity.sol";
import { OnChainIdentityWithRevocation } from "./extensions/OnChainIdentityWithRevocation.sol";

/// @title SMART Identity Implementation Contract (Logic for Wallet Identities)
/// @author SettleMint Tokenization Services
/// @notice This contract provides the upgradeable logic for standard on-chain identities associated with user wallets
///         within the SMART Protocol. It implements `IIdentity` using local `ERC734` and `ERC735` extensions.
/// @dev This contract is intended to be deployed once and then used as the logic implementation target for multiple
///      `SMARTIdentityProxy` contracts. It inherits `ERC734` for key management, `ERC735` for claim management,
///      `ERC165Upgradeable` for interface detection, and `ERC2771ContextUpgradeable` for meta-transactions.
contract SMARTIdentityImplementation is
    ISMARTIdentity,
    ERC734,
    ERC735,
    OnChainIdentityWithRevocation,
    ERC165Upgradeable,
    ERC2771ContextUpgradeable
{
    // --- State Variables ---
    bool private _smartIdentityInitialized;

    // --- Custom Errors for SMARTIdentityImplementation ---
    error AlreadyInitialized();
    error InvalidInitialManagementKey();
    error SenderLacksManagementKey();
    error SenderLacksActionKey();
    error SenderLacksClaimSignerKey();
    // Errors for checks that might be redundant if ERC734.sol handles them robustly
    error ReplicatedExecutionIdDoesNotExist(uint256 executionId);
    error ReplicatedExecutionAlreadyPerformed(uint256 executionId);

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

    // --- OnchainIdentityWithRevocation Functions ---
    /// @dev Revokes a claim by its signature
    /// @param signature The signature of the claim to revoke
    function revokeClaimBySignature(bytes calldata signature) external virtual override onlyManager {
        _revokeClaimBySignature(signature);
    }

    /// @dev Revokes a claim by its ID
    /// @param _claimId The ID of the claim to revoke
    function revokeClaim(bytes32 _claimId) external virtual override onlyManager returns (bool) {
        return _revokeClaim(_claimId);
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

    function keyHasPurpose(
        bytes32 _key,
        uint256 _purpose
    )
        public
        view
        virtual
        override(ERC734, OnChainIdentity, IERC734)
        returns (bool exists)
    {
        return super.keyHasPurpose(_key, _purpose);
    }

    // --- ERC735 (Claim Holder) Functions - Overridden for Access Control ---

    /// @inheritdoc IERC735
    /// @dev Adds or updates a claim. Requires CLAIM_SIGNER_KEY purpose from the sender.
    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address _issuer,
        bytes memory _signature,
        bytes memory _data,
        string memory _uri
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

    function getClaim(bytes32 _claimId)
        public
        view
        virtual
        override(ERC735, OnChainIdentityWithRevocation, IERC735)
        returns (uint256, uint256, address, bytes memory, bytes memory, string memory)
    {
        return ERC735.getClaim(_claimId);
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
