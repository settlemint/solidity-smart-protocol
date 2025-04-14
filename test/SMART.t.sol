// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { MySMARTTokenFactory } from "../contracts/MySMARTTokenFactory.sol";
import { Identity } from "../contracts/onchainid/Identity.sol";
import { IdentityRegistryStorage } from "../contracts/SMART/SMARTIdentityRegistryStorage.sol";
import { TrustedIssuersRegistry } from "../contracts/SMART/SMARTTrustedIssuersRegistry.sol";
import { IdentityRegistry } from "../contracts/SMART/SMARTIdentityRegistry.sol";
import { Compliance } from "../contracts/SMART/SMARTCompliance.sol";
import { SMARTIdentityFactory } from "../contracts/SMART/SMARTIdentityFacory.sol";

contract CounterTest is Test {
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
        identityRegistry = new SMARTIdentityRegistry(identityRegistryStorage, trustedIssuersRegistry);
        compliance = new SMARTCompliance();

        factory = new MySMARTTokenFactory(address(identityRegistry), address(compliance));

        identityFactory = new SMARTIdentityFactory();

        vm.stopPrank();
    }

    function createClientIdentity(address clientWalletAddress_, uint16 countryCode_) public {
        vm.startPrank(platformAdmin);

        // Create the identity using the factory
        address identity = identityFactory.createIdentity(clientWalletAddress_);

        // Register the identity in the registry
        identityRegistry.registerIdentity(clientWalletAddress_, IIdentity(identity), countryCode_);

        vm.stopPrank();
    }

    function test_Mint() public {
        vm.startPrank(platformAdmin);

        // Create the client identity
        createClientIdentity(client1, 56);

        vm.stopPrank();
    }
}
