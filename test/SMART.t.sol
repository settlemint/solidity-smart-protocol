// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { MySMARTTokenFactory } from "../contracts/MySMARTTokenFactory.sol";
import { Identity } from "../contracts/onchainid/Identity.sol";
import { IIdentity } from "../contracts/onchainid/interface/IIdentity.sol";
import { SMARTIdentityRegistryStorage } from "../contracts/SMART/SMARTIdentityRegistryStorage.sol";
import { SMARTTrustedIssuersRegistry } from "../contracts/SMART/SMARTTrustedIssuersRegistry.sol";
import { SMARTIdentityRegistry } from "../contracts/SMART/SMARTIdentityRegistry.sol";
import { SMARTCompliance } from "../contracts/SMART/SMARTCompliance.sol";
import { SMARTIdentityFactory } from "../contracts/SMART/SMARTIdentityFactory.sol";

contract SMARTTest is Test {
    address public platformAdmin = makeAddr("Platform Admin");
    address public client1 = makeAddr("Client 1");

    SMARTIdentityRegistryStorage identityRegistryStorage;
    SMARTTrustedIssuersRegistry trustedIssuersRegistry;
    SMARTIdentityRegistry identityRegistry;
    SMARTCompliance compliance;

    MySMARTTokenFactory factory;

    SMARTIdentityFactory identityFactory;

    function setUp() public {
        vm.startPrank(platformAdmin);

        identityRegistryStorage = new SMARTIdentityRegistryStorage();
        trustedIssuersRegistry = new SMARTTrustedIssuersRegistry();
        identityRegistry = new SMARTIdentityRegistry(address(identityRegistryStorage), address(trustedIssuersRegistry));
        // This is part of the ERC3643 standard. Not sure if we want to keep this?
        // It is to allow the identity registry to execute functions on the storage contract.
        identityRegistryStorage.bindIdentityRegistry(address(identityRegistry));

        compliance = new SMARTCompliance();
        identityFactory = new SMARTIdentityFactory();

        factory = new MySMARTTokenFactory(address(identityRegistry), address(compliance));

        vm.stopPrank();
    }

    function createClientIdentity(address clientWalletAddress_, uint16 countryCode_) public {
        vm.startPrank(platformAdmin);

        // Create the identity using the factory
        address identity = identityFactory.createIdentity(clientWalletAddress_, new bytes32[](0));

        // Register the identity in the registry
        identityRegistry.registerIdentity(clientWalletAddress_, IIdentity(identity), countryCode_);

        vm.stopPrank();
    }

    function test_Mint() public {
        // Create the client identity
        createClientIdentity(client1, 56);
    }
}
