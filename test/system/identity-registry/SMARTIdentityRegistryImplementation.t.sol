// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../../contracts/interface/ISMARTIdentityRegistry.sol";
import "../../../contracts/system/identity-registry/SMARTIdentityRegistryImplementation.sol";
import "../../utils/SystemUtils.sol";
import "../../utils/IdentityUtils.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
import { IERC3643TrustedIssuersRegistry } from "../../../contracts/interface/ERC-3643/IERC3643TrustedIssuersRegistry.sol";

contract SMARTIdentityRegistryImplementationTest is Test {
    SystemUtils public systemUtils;
    IdentityUtils public identityUtils;
    ISMARTIdentityRegistry public identityRegistry;
    address public admin;
    address public user1;
    address public user2;
    address public unauthorizedUser;
    
    IIdentity public identity1;
    IIdentity public identity2;
    uint16 public constant COUNTRY_US = 840;
    uint16 public constant COUNTRY_UK = 826;
    uint256[] public claimTopics;

    event IdentityStorageSet(address indexed admin, address indexed identityStorage);
    event TrustedIssuersRegistrySet(address indexed admin, address indexed trustedIssuersRegistry);
    event IdentityRegistered(address indexed registrar, address indexed userAddress, IIdentity indexed identity);
    event IdentityRemoved(address indexed registrar, address indexed userAddress, IIdentity indexed identity);
    event CountryUpdated(address indexed sender, address indexed _investorAddress, uint16 indexed _country);
    event IdentityUpdated(address indexed registrar, IIdentity indexed oldIdentity, IIdentity indexed newIdentity);

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        unauthorizedUser = makeAddr("unauthorizedUser");

        systemUtils = new SystemUtils(admin);
        identityRegistry = systemUtils.identityRegistry();
        
        identityUtils = new IdentityUtils(
            admin,
            systemUtils.identityFactory(),
            identityRegistry,
            systemUtils.trustedIssuersRegistry()
        );
        
        vm.startPrank(admin);
        
        // Create test identities
        address identity1Addr = identityUtils.createIdentity(user1);
        address identity2Addr = identityUtils.createIdentity(user2);
        identity1 = IIdentity(identity1Addr);
        identity2 = IIdentity(identity2Addr);
        
        // Setup claim topics for testing
        claimTopics.push(1); // KYC topic
        claimTopics.push(2); // AML topic
        
        vm.stopPrank();
    }

    function testInitialState() public view {
        assertTrue(address(identityRegistry.identityStorage()) != address(0));
        assertTrue(address(identityRegistry.issuersRegistry()) != address(0));
        // Cast to implementation to access supportsInterface
        SMARTIdentityRegistryImplementation impl = SMARTIdentityRegistryImplementation(address(identityRegistry));
        assertTrue(impl.supportsInterface(type(ISMARTIdentityRegistry).interfaceId));
    }

    function testRegisterIdentity() public {
        vm.expectEmit(true, true, true, true);
        emit IdentityRegistered(admin, user1, identity1);

        vm.prank(admin);
        identityRegistry.registerIdentity(user1, identity1, COUNTRY_US);

        assertTrue(identityRegistry.contains(user1));
        assertEq(address(identityRegistry.identity(user1)), address(identity1));
        assertEq(identityRegistry.investorCountry(user1), COUNTRY_US);
    }

    function testRegisterIdentityRevertsWithZeroUser() public {
        vm.prank(admin);
        vm.expectRevert(SMARTIdentityRegistryImplementation.InvalidUserAddress.selector);
        identityRegistry.registerIdentity(address(0), identity1, COUNTRY_US);
    }

    function testRegisterIdentityRevertsWithZeroIdentity() public {
        vm.prank(admin);
        vm.expectRevert(SMARTIdentityRegistryImplementation.InvalidIdentityAddress.selector);
        identityRegistry.registerIdentity(user1, IIdentity(address(0)), COUNTRY_US);
    }

    function testRegisterIdentityRevertsIfAlreadyRegistered() public {
        vm.startPrank(admin);
        
        identityRegistry.registerIdentity(user1, identity1, COUNTRY_US);
        
        vm.expectRevert(abi.encodeWithSelector(SMARTIdentityRegistryImplementation.IdentityAlreadyRegistered.selector, user1));
        identityRegistry.registerIdentity(user1, identity2, COUNTRY_UK);
        
        vm.stopPrank();
    }

    function testRegisterIdentityRevertsWithUnauthorizedCaller() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        identityRegistry.registerIdentity(user1, identity1, COUNTRY_US);
    }

    function testDeleteIdentity() public {
        vm.startPrank(admin);
        
        identityRegistry.registerIdentity(user1, identity1, COUNTRY_US);
        assertTrue(identityRegistry.contains(user1));

        vm.expectEmit(true, true, true, true);
        emit IdentityRemoved(admin, user1, identity1);

        identityRegistry.deleteIdentity(user1);
        
        assertFalse(identityRegistry.contains(user1));
        
        vm.stopPrank();
    }

    function testDeleteIdentityRevertsIfNotRegistered() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SMARTIdentityRegistryImplementation.IdentityNotRegistered.selector, user1));
        identityRegistry.deleteIdentity(user1);
    }

    function testDeleteIdentityRevertsWithUnauthorizedCaller() public {
        vm.startPrank(admin);
        identityRegistry.registerIdentity(user1, identity1, COUNTRY_US);
        vm.stopPrank();

        vm.prank(unauthorizedUser);
        vm.expectRevert();
        identityRegistry.deleteIdentity(user1);
    }

    function testUpdateCountry() public {
        vm.startPrank(admin);
        
        identityRegistry.registerIdentity(user1, identity1, COUNTRY_US);
        
        vm.expectEmit(true, true, false, true);
        emit CountryUpdated(admin, user1, COUNTRY_UK);

        identityRegistry.updateCountry(user1, COUNTRY_UK);
        
        assertEq(identityRegistry.investorCountry(user1), COUNTRY_UK);
        
        vm.stopPrank();
    }

    function testUpdateCountryRevertsIfNotRegistered() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SMARTIdentityRegistryImplementation.IdentityNotRegistered.selector, user1));
        identityRegistry.updateCountry(user1, COUNTRY_UK);
    }

    function testUpdateCountryRevertsWithUnauthorizedCaller() public {
        vm.startPrank(admin);
        identityRegistry.registerIdentity(user1, identity1, COUNTRY_US);
        vm.stopPrank();

        vm.prank(unauthorizedUser);
        vm.expectRevert();
        identityRegistry.updateCountry(user1, COUNTRY_UK);
    }

    function testUpdateIdentity() public {
        vm.startPrank(admin);
        
        identityRegistry.registerIdentity(user1, identity1, COUNTRY_US);
        
        vm.expectEmit(true, true, true, true);
        emit IdentityUpdated(admin, identity1, identity2);

        identityRegistry.updateIdentity(user1, identity2);
        
        assertEq(address(identityRegistry.identity(user1)), address(identity2));
        
        vm.stopPrank();
    }

    function testUpdateIdentityRevertsIfNotRegistered() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SMARTIdentityRegistryImplementation.IdentityNotRegistered.selector, user1));
        identityRegistry.updateIdentity(user1, identity2);
    }

    function testUpdateIdentityRevertsWithZeroIdentity() public {
        vm.startPrank(admin);
        
        identityRegistry.registerIdentity(user1, identity1, COUNTRY_US);
        
        vm.expectRevert(SMARTIdentityRegistryImplementation.InvalidIdentityAddress.selector);
        identityRegistry.updateIdentity(user1, IIdentity(address(0)));
        
        vm.stopPrank();
    }

    function testUpdateIdentityRevertsWithUnauthorizedCaller() public {
        vm.startPrank(admin);
        identityRegistry.registerIdentity(user1, identity1, COUNTRY_US);
        vm.stopPrank();

        vm.prank(unauthorizedUser);
        vm.expectRevert();
        identityRegistry.updateIdentity(user1, identity2);
    }

    function testBatchRegisterIdentity() public {
        address[] memory users = new address[](2);
        IIdentity[] memory identities = new IIdentity[](2);
        uint16[] memory countries = new uint16[](2);
        
        users[0] = user1;
        users[1] = user2;
        identities[0] = identity1;
        identities[1] = identity2;
        countries[0] = COUNTRY_US;
        countries[1] = COUNTRY_UK;

        vm.prank(admin);
        identityRegistry.batchRegisterIdentity(users, identities, countries);

        assertTrue(identityRegistry.contains(user1));
        assertTrue(identityRegistry.contains(user2));
        assertEq(address(identityRegistry.identity(user1)), address(identity1));
        assertEq(address(identityRegistry.identity(user2)), address(identity2));
        assertEq(identityRegistry.investorCountry(user1), COUNTRY_US);
        assertEq(identityRegistry.investorCountry(user2), COUNTRY_UK);
    }

    function testBatchRegisterIdentityRevertsWithMismatchedArrays() public {
        address[] memory users = new address[](2);
        IIdentity[] memory identities = new IIdentity[](1); // Different length
        uint16[] memory countries = new uint16[](2);
        
        users[0] = user1;
        users[1] = user2;
        identities[0] = identity1;
        countries[0] = COUNTRY_US;
        countries[1] = COUNTRY_UK;

        vm.prank(admin);
        vm.expectRevert(SMARTIdentityRegistryImplementation.ArrayLengthMismatch.selector);
        identityRegistry.batchRegisterIdentity(users, identities, countries);
    }

    function testBatchRegisterIdentityRevertsWithUnauthorizedCaller() public {
        address[] memory users = new address[](1);
        IIdentity[] memory identities = new IIdentity[](1);
        uint16[] memory countries = new uint16[](1);
        
        users[0] = user1;
        identities[0] = identity1;
        countries[0] = COUNTRY_US;

        vm.prank(unauthorizedUser);
        vm.expectRevert();
        identityRegistry.batchRegisterIdentity(users, identities, countries);
    }

    function testContainsReturnsFalseForUnregistered() public view {
        assertFalse(identityRegistry.contains(user1));
    }

    function testContainsReturnsTrueForRegistered() public {
        vm.prank(admin);
        identityRegistry.registerIdentity(user1, identity1, COUNTRY_US);

        assertTrue(identityRegistry.contains(user1));
    }

    function testIsVerifiedReturnsFalseForUnregistered() public view {
        assertFalse(identityRegistry.isVerified(user1, claimTopics));
    }

    function testIsVerifiedReturnsTrueForEmptyClaimTopics() public {
        vm.prank(admin);
        identityRegistry.registerIdentity(user1, identity1, COUNTRY_US);

        uint256[] memory emptyTopics = new uint256[](0);
        assertTrue(identityRegistry.isVerified(user1, emptyTopics));
    }

    function testIsVerifiedWithClaimTopics() public {
        vm.prank(admin);
        identityRegistry.registerIdentity(user1, identity1, COUNTRY_US);

        // Should return false since we haven't set up proper claims
        assertFalse(identityRegistry.isVerified(user1, claimTopics));
    }

    function testInvestorCountryRevertsIfNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(SMARTIdentityRegistryImplementation.IdentityNotRegistered.selector, user1));
        identityRegistry.investorCountry(user1);
    }

    function testSetIdentityRegistryStorage() public {
        address newStorage = makeAddr("newStorage");
        
        vm.expectEmit(true, true, false, false);
        emit IdentityStorageSet(admin, newStorage);

        vm.prank(admin);
        identityRegistry.setIdentityRegistryStorage(newStorage);

        assertEq(address(identityRegistry.identityStorage()), newStorage);
    }

    function testSetIdentityRegistryStorageRevertsWithZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(SMARTIdentityRegistryImplementation.InvalidStorageAddress.selector);
        identityRegistry.setIdentityRegistryStorage(address(0));
    }

    function testSetIdentityRegistryStorageRevertsWithUnauthorizedCaller() public {
        address newStorage = makeAddr("newStorage");
        
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        identityRegistry.setIdentityRegistryStorage(newStorage);
    }

    function testSetTrustedIssuersRegistry() public {
        address newRegistry = makeAddr("newRegistry");
        
        vm.expectEmit(true, true, false, false);
        emit TrustedIssuersRegistrySet(admin, newRegistry);

        vm.prank(admin);
        identityRegistry.setTrustedIssuersRegistry(newRegistry);

        assertEq(address(identityRegistry.issuersRegistry()), newRegistry);
    }

    function testSetTrustedIssuersRegistryRevertsWithZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(SMARTIdentityRegistryImplementation.InvalidRegistryAddress.selector);
        identityRegistry.setTrustedIssuersRegistry(address(0));
    }

    function testSetTrustedIssuersRegistryRevertsWithUnauthorizedCaller() public {
        address newRegistry = makeAddr("newRegistry");
        
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        identityRegistry.setTrustedIssuersRegistry(newRegistry);
    }

    function testSupportsInterface() public view {
        SMARTIdentityRegistryImplementation impl = SMARTIdentityRegistryImplementation(address(identityRegistry));
        assertTrue(impl.supportsInterface(type(ISMARTIdentityRegistry).interfaceId));
        assertTrue(impl.supportsInterface(type(IERC165).interfaceId));
        assertTrue(impl.supportsInterface(type(IAccessControl).interfaceId));
    }

    function testAccessControlRoles() public view {
        SMARTIdentityRegistryImplementation impl = SMARTIdentityRegistryImplementation(address(identityRegistry));
        assertTrue(impl.hasRole(impl.DEFAULT_ADMIN_ROLE(), admin));
    }
}