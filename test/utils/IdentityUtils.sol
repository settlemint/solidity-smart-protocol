// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { SMARTIdentityFactory } from "../../contracts/SMART/SMARTIdentityFactory.sol";
import { SMARTIdentityRegistry } from "../../contracts/SMART/SMARTIdentityRegistry.sol";
import { SMARTTrustedIssuersRegistry } from "../../contracts/SMART/SMARTTrustedIssuersRegistry.sol";
import { IIdentity } from "../../contracts/onchainid/interface/IIdentity.sol";
import { IClaimIssuer } from "../../contracts/onchainid/interface/IClaimIssuer.sol";

contract IdentityUtils is Test {
    address internal _platformAdmin;
    SMARTIdentityFactory internal _identityFactory;
    SMARTIdentityRegistry internal _identityRegistry;
    SMARTTrustedIssuersRegistry internal _trustedIssuersRegistry;

    constructor(
        address platformAdmin_,
        SMARTIdentityFactory identityFactory_,
        SMARTIdentityRegistry identityRegistry_,
        SMARTTrustedIssuersRegistry trustedIssuersRegistry_
    ) {
        _platformAdmin = platformAdmin_;
        _identityFactory = identityFactory_;
        _identityRegistry = identityRegistry_;
        _trustedIssuersRegistry = trustedIssuersRegistry_;
    }

    /**
     * @notice Creates a basic identity contract.
     * @param walletAddress_ The wallet address to associate with the identity.
     * @return The address of the newly created identity contract.
     */
    function createIdentity(address walletAddress_) public returns (address) {
        vm.startPrank(_platformAdmin);
        address identity = _identityFactory.createIdentity(walletAddress_, new bytes32[](0));
        vm.stopPrank();
        return identity;
    }

    /**
     * @notice Creates an identity for a client and registers it.
     * @param clientWalletAddress_ The client's wallet address.
     * @param countryCode_ The country code for the client.
     * @return The address of the newly created and registered identity contract.
     */
    function createClientIdentity(address clientWalletAddress_, uint16 countryCode_) public returns (address) {
        // Create the identity using the factory
        address identity = createIdentity(clientWalletAddress_);

        // Register the identity in the registry
        vm.startPrank(_platformAdmin);
        _identityRegistry.registerIdentity(clientWalletAddress_, IIdentity(identity), countryCode_);
        vm.stopPrank();

        return identity;
    }

    /**
     * @notice Creates an identity for a claim issuer and adds it to the trusted registry.
     * @param issuerWalletAddress_ The issuer's wallet address.
     * @param claimTopics The claim topics the issuer is trusted for.
     * @return The address of the newly created and registered issuer identity contract.
     */
    function createIssuerIdentity(
        address issuerWalletAddress_,
        uint256[] memory claimTopics
    )
        public
        returns (address)
    {
        // Create the identity using the factory
        address issuerIdentityAddr = createIdentity(issuerWalletAddress_);

        vm.startPrank(_platformAdmin);
        // IMPORTANT: Cast the *identity address* to IClaimIssuer for the registry
        _trustedIssuersRegistry.addTrustedIssuer(IClaimIssuer(issuerIdentityAddr), claimTopics);
        vm.stopPrank();

        return issuerIdentityAddr; // Return the created identity address
    }
}
