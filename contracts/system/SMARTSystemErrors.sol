// SPDX-License-Identifier: FSL-1.1-MIT

pragma solidity ^0.8.28;

error InvalidSystemAddress();
error InitializationFailed();
error ComplianceImplementationNotSet();
error IdentityRegistryImplementationNotSet();
error IdentityRegistryStorageImplementationNotSet();
error TrustedIssuersRegistryImplementationNotSet();
error IdentityFactoryImplementationNotSet();
error IdentityImplementationNotSet();
error TokenIdentityImplementationNotSet();
error IndexOutOfBounds(uint256 index, uint256 length);
error ETHTransfersNotAllowed();
error InvalidImplementationInterface(address implAddress, bytes4 interfaceId);
error EtherWithdrawalFailed();
error InvalidTokenFactoryAddress();
error TokenFactoryImplementationNotSet(bytes32 registryTypeHash);
error TokenFactoryTypeAlreadyRegistered(bytes32 registryTypeHash);
error TokenImplementationNotSet();
