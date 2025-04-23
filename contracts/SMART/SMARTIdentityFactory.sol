// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.27;

// import { Identity } from "../onchainid/Identity.sol"; // No longer needed directly
// import { IIdentity } from "../onchainid/interface/IIdentity.sol"; // No longer needed directly
import { IERC734 } from "../onchainid/interface/IERC734.sol";
import { IdentityProxy } from "../onchainid/proxy/IdentityProxy.sol"; // Import IdentityProxy
import { IImplementationAuthority } from "../onchainid/interface/IImplementationAuthority.sol"; // Import
    // IImplementationAuthority
// import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol"; // Remove ERC1967Proxy
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol"; // Remove
// UUPSUpgradeable
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

// --- Errors ---
error ZeroAddressNotAllowed();
error SaltAlreadyTaken();
error WalletAlreadyLinked();
error WalletInManagementKeys();
error TokenAlreadyLinked();
// error InvalidImplementationAddress(); // Remove or rename
error InvalidAuthorityAddress(); // New error

/// @title SMARTIdentityFactory
/// @notice Factory for creating deterministic OnchainID identities (using IdentityProxy) for wallets and tokens,
/// managed by an ImplementationAuthority.
contract SMARTIdentityFactory is
    Initializable,
    ERC2771ContextUpgradeable,
    OwnableUpgradeable // Remove UUPSUpgradeable
{
    // --- Storage Variables ---
    // address private _identityImplementation; // Remove direct implementation address
    address private _implementationAuthority; // Store authority address

    mapping(string => bool) private _saltTaken;
    mapping(address => address) private _identities;
    mapping(address => address) private _tokenIdentities;

    // --- Events ---
    event IdentityCreated(address indexed identity, address indexed wallet);
    event TokenIdentityCreated(address indexed identity, address indexed token);
    // event IdentityImplementationSet(address indexed newImplementation); // Remove event for direct implementation
    event ImplementationAuthoritySet(address indexed newAuthority); // Add event for authority

    // --- Constructor ---
    constructor() ERC2771ContextUpgradeable(address(0)) {
        _disableInitializers();
    }

    // --- Initializer ---
    function initialize(address initialOwner, address implementationAuthority_) public initializer {
        // if (identityImplementation_ == address(0)) revert InvalidImplementationAddress(); // Adjust check
        if (implementationAuthority_ == address(0)) revert InvalidAuthorityAddress();
        __Ownable_init(initialOwner);
        // __UUPSUpgradeable_init(); // Remove UUPS init
        // _identityImplementation = identityImplementation_; // Store authority instead
        _implementationAuthority = implementationAuthority_;
        // emit IdentityImplementationSet(identityImplementation_); // Emit new event
        emit ImplementationAuthoritySet(implementationAuthority_);
    }

    // --- State-Changing Functions ---
    function createIdentity(address _wallet, bytes32[] memory _managementKeys) external onlyOwner returns (address) {
        if (_wallet == address(0)) revert ZeroAddressNotAllowed();
        if (_identities[_wallet] != address(0)) revert WalletAlreadyLinked();

        // Pass _wallet as initial owner to internal function
        address identity = _createIdentityInternal("OID", _wallet, _wallet);

        // Add management keys if provided
        if (_managementKeys.length > 0) {
            // Add keys *after* deployment and initialization via proxy constructor
            IERC734 identityContract = IERC734(identity);
            // Remove the deployer/initial owner key added by proxy constructor
            identityContract.removeKey(keccak256(abi.encode(_wallet)), 1);
            // Add the specified management keys
            for (uint256 i = 0; i < _managementKeys.length; i++) {
                if (_managementKeys[i] == keccak256(abi.encode(_wallet))) {
                    revert WalletInManagementKeys(); // This check might be redundant if we remove _wallet key anyway
                }
                identityContract.addKey(_managementKeys[i], 1, 1);
            }
        }

        _identities[_wallet] = identity;

        emit IdentityCreated(identity, _wallet);
        return identity;
    }

    function getIdentity(address _wallet) external view returns (address) {
        return _identities[_wallet];
    }

    function createTokenIdentity(address _token, address _tokenOwner) external onlyOwner returns (address) {
        if (_token == address(0)) revert ZeroAddressNotAllowed();
        if (_tokenOwner == address(0)) revert ZeroAddressNotAllowed();
        if (_tokenIdentities[_token] != address(0)) revert TokenAlreadyLinked();

        // Pass _tokenOwner as initial owner to internal function
        address identity = _createIdentityInternal("Token", _token, _tokenOwner);

        _tokenIdentities[_token] = identity;

        emit TokenIdentityCreated(identity, _token);
        return identity;
    }

    // --- View Functions ---
    function getTokenIdentity(address _token) external view returns (address) {
        return _tokenIdentities[_token];
    }

    /**
     * @notice Computes the deterministic address for an IdentityProxy.
     * @param _salt A unique string salt combined with the entity address.
     * @param _wallet The address that will be the initial management key for the proxy.
     */
    function getAddress(string memory _salt, address _wallet) public view returns (address) {
        bytes memory proxyBytecode = type(IdentityProxy).creationCode;
        // Constructor arguments for IdentityProxy: address implementationAuthority, address initialManagementKey
        bytes memory constructorArgs = abi.encode(_implementationAuthority, _wallet);

        return Create2.computeAddress(
            bytes32(keccak256(abi.encodePacked(_salt))), // Use the combined salt directly
            keccak256(abi.encodePacked(proxyBytecode, constructorArgs)) // Hash bytecode + constructor args
        );
    }

    /**
     * @notice Returns the address of the ImplementationAuthority contract managing the identities.
     */
    function getImplementationAuthority() external view returns (address) {
        // return _identityImplementation; // Return authority address
        return _implementationAuthority;
    }

    // --- Internal Functions ---

    /**
     * @dev Internal function to compute salt, check availability, and deploy the identity.
     * @param _saltPrefix Prefix for the salt ("OID" or "Token").
     * @param _entityAddress The address of the wallet or token being identified.
     * @param _initialOwnerAddress The address to set as the initial management key in the IdentityProxy constructor.
     */
    function _createIdentityInternal(
        string memory _saltPrefix,
        address _entityAddress,
        address _initialOwnerAddress
    )
        private
        returns (address)
    {
        // Generate salt based on prefix and entity address
        string memory saltString = string.concat(_saltPrefix, Strings.toHexString(_entityAddress));
        bytes32 saltBytes = keccak256(abi.encodePacked(saltString));

        if (_saltTaken[saltString]) revert SaltAlreadyTaken(); // Check using string salt

        // Deploy using the initial owner address for the proxy constructor
        address identity = _deployIdentity(saltBytes, _initialOwnerAddress);
        _saltTaken[saltString] = true; // Mark string salt as taken
        return identity;
    }

    /**
     * @dev Deploys an IdentityProxy using Create2.
     * Uses the factory's stored ImplementationAuthority address.
     * @param _saltBytes The keccak256 hash of the unique salt string.
     * @param _initialOwner The address to be passed as initialManagementKey to the IdentityProxy constructor.
     * @return The address of the deployed IdentityProxy.
     */
    function _deployIdentity(bytes32 _saltBytes, address _initialOwner) private returns (address) {
        address addr = getAddressForByteSalt(_saltBytes, _initialOwner);

        bytes memory proxyBytecode = type(IdentityProxy).creationCode;
        // Constructor arguments for IdentityProxy: address implementationAuthority, address initialManagementKey
        bytes memory constructorArgs = abi.encode(_implementationAuthority, _initialOwner);

        // Using OZ Create2 deploy
        bytes memory bytecode = abi.encodePacked(proxyBytecode, constructorArgs);
        address deployedAddress = Create2.deploy(0, _saltBytes, bytecode);

        // Sanity check: Ensure deployment address matches calculated address
        require(deployedAddress == addr, "SMARTIdentityFactory: Deployment address mismatch");
        return deployedAddress;
    }

    /**
     * @dev Computes the deterministic address for an IdentityProxy using a bytes32 salt.
     * @param _saltBytes The keccak256 hash of the unique salt string.
     * @param _wallet The address that will be the initial management key for the proxy.
     */
    function getAddressForByteSalt(bytes32 _saltBytes, address _wallet) public view returns (address) {
        bytes memory proxyBytecode = type(IdentityProxy).creationCode;
        bytes memory constructorArgs = abi.encode(_implementationAuthority, _wallet);
        return Create2.computeAddress(_saltBytes, keccak256(abi.encodePacked(proxyBytecode, constructorArgs)));
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
    // function _authorizeUpgrade(address newImplementation) internal override(UUPSUpgradeable) onlyOwner { } // Remove
    // UUPS function
}
