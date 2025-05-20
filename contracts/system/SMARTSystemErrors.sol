// SPDX-License-Identifier: FSL-1.1-MIT

pragma solidity ^0.8.28;

/// @notice Error indicating that an invalid system address was provided or encountered.
/// @dev This typically means an address expected to be a core system component (like a module proxy or implementation)
/// was found to be the zero address or an otherwise incorrect address during a critical operation.
error InvalidSystemAddress();

/// @notice Error indicating that a system initialization process failed.
/// @dev This could occur during the `bootstrap` phase of the `SMARTSystem` or during the constructor execution
/// of a critical component if a required setup step could not be completed successfully.
error InitializationFailed();

/// @notice Error indicating that the compliance module implementation address has not been set.
/// @dev This error is thrown if an operation requires the compliance module, but its logic contract address is
/// zero or has not been configured in the `SMARTSystem`.
error ComplianceImplementationNotSet();

/// @notice Error indicating that the identity registry implementation address has not been set.
/// @dev This error is thrown if an operation requires the identity registry, but its logic contract address is
/// zero or has not been configured in the `SMARTSystem`.
error IdentityRegistryImplementationNotSet();

/// @notice Error indicating that the identity registry storage implementation address has not been set.
/// @dev This error is thrown if an operation requires the identity registry storage, but its logic contract address is
/// zero or has not been configured in the `SMARTSystem`.
error IdentityRegistryStorageImplementationNotSet();

/// @notice Error indicating that the trusted issuers registry implementation address has not been set.
/// @dev This error is thrown if an operation requires the trusted issuers registry, but its logic contract address is
/// zero or has not been configured in the `SMARTSystem`.
error TrustedIssuersRegistryImplementationNotSet();

/// @notice Error indicating that the identity factory implementation address has not been set.
/// @dev This error is thrown if an operation requires the identity factory, but its logic contract address is
/// zero or has not been configured in the `SMARTSystem`.
error IdentityFactoryImplementationNotSet();

/// @notice Error indicating that the standard identity contract implementation address has not been set.
/// @dev This error is thrown if an operation requires the standard identity implementation (the template for user
/// identities), but its logic contract address is zero or has not been configured in the `SMARTSystem`.
error IdentityImplementationNotSet();

/// @notice Error indicating that the token identity contract implementation address has not been set.
/// @dev This error is thrown if an operation requires the token identity implementation (the template for
/// token-specific
/// identities), but its logic contract address is zero or has not been configured in the `SMARTSystem`.
error TokenIdentityImplementationNotSet();

/// @notice Error indicating that the token access manager contract implementation address has not been set.
/// @dev This error is thrown if an operation requires the token access manager implementation, but its logic
/// contract address is zero or has not been configured in the `SMARTSystem`.
error TokenAccessManagerImplementationNotSet();

/// @notice Error indicating that an index provided for accessing an array or list is out of its valid range.
/// @dev For example, trying to access the 5th element in an array that only has 3 elements.
/// @param index The invalid index that was attempted to be accessed.
/// @param length The actual length or size of the array/list.
error IndexOutOfBounds(uint256 index, uint256 length);

/// @notice Error indicating that an attempt was made to send Ether to a contract that does not allow or expect it.
/// @dev Many contracts are not designed to receive or hold Ether directly, and will revert such transactions to prevent
/// loss of funds or unexpected behavior.
error ETHTransfersNotAllowed();

/// @notice Error indicating that a provided implementation address does not support a required interface.
/// @dev When setting implementation addresses for modules (e.g., compliance, identity registry), the `SMARTSystem`
/// checks if these implementations adhere to specific standard interfaces (like `IERC165` and the module-specific
/// interface). If this check fails, this error is thrown.
/// @param implAddress The address of the implementation contract that failed the interface check.
/// @param interfaceId The bytes4 identifier of the interface that the `implAddress` was expected to support.
error InvalidImplementationInterface(address implAddress, bytes4 interfaceId);

/// @notice Error indicating that an attempt to withdraw Ether from a contract failed.
/// @dev This can happen if the contract does not have enough Ether, or if the recipient address cannot accept Ether
/// (e.g., it's a contract without a payable fallback/receive function that reverts on Ether receipt).
error EtherWithdrawalFailed();

/// @notice Error indicating that an invalid token factory address was provided.
error InvalidTokenFactoryAddress();

/// @notice Error indicating that the token factory implementation address has not been set.
error TokenFactoryImplementationNotSet(bytes32 registryTypeHash);

/// @notice Error indicating that a token factory type hash has already been registered.
error TokenFactoryTypeAlreadyRegistered(bytes32 registryTypeHash);

/// @notice Error indicating that the token implementation address has not been set.
error TokenImplementationNotSet();

/// @notice Error indicating that an invalid token implementation address was provided.
error InvalidTokenImplementationAddress();

/// @notice Error indicating that an invalid token implementation interface was provided.
error InvalidTokenImplementationInterface();

/// @notice Error indicating that an attempt was made to initialize a component with a zero address for its
/// implementation.
/// @dev This typically occurs in proxy constructors if the logic contract address fetched from the system is
/// address(0).
error InitializationWithZeroAddress();
