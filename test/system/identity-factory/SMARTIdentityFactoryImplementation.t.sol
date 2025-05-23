// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../../contracts/system/identity-factory/ISMARTIdentityFactory.sol";
import "../../utils/SystemUtils.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract SMARTIdentityFactoryImplementationTest is Test {
    SystemUtils public systemUtils;
    ISMARTIdentityFactory public factory;
    address public admin;
    address public user;
    address public unauthorizedUser;
    
    address public accessManager;

    event IdentityCreated(address indexed sender, address indexed identity, address indexed wallet);
    event TokenIdentityCreated(address indexed sender, address indexed identity, address indexed token);

    function setUp() public {
        admin = makeAddr("admin");
        user = makeAddr("user");
        unauthorizedUser = makeAddr("unauthorizedUser");

        systemUtils = new SystemUtils(admin);
        
        vm.startPrank(admin);
        
        address[] memory initialAdmins = new address[](1);
        initialAdmins[0] = admin;
        accessManager = address(systemUtils.createTokenAccessManager(initialAdmins));
        
        factory = systemUtils.identityFactory();
        
        vm.stopPrank();
    }


    function testCreateIdentity() public {
        bytes32[] memory managementKeys = new bytes32[](0);
        
        vm.expectEmit(true, false, true, true);
        emit IdentityCreated(admin, address(0), user); // address(0) will be replaced with actual

        vm.prank(admin);
        address identity = factory.createIdentity(user, managementKeys);

        assertTrue(identity != address(0));
        assertEq(factory.getIdentity(user), identity);
    }

    function testCreateTokenIdentity() public {
        address tokenAddress = makeAddr("token");
        
        vm.expectEmit(true, false, true, true);
        emit TokenIdentityCreated(admin, address(0), tokenAddress); // address(0) will be replaced with actual

        vm.prank(admin);
        address identity = factory.createTokenIdentity(tokenAddress, accessManager);

        assertTrue(identity != address(0));
        assertEq(factory.getTokenIdentity(tokenAddress), identity);
    }



    function testCreateIdentityRevertsWithUnauthorizedCaller() public {
        bytes32[] memory managementKeys = new bytes32[](0);
        
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        factory.createIdentity(user, managementKeys);
    }

    function testCreateTokenIdentityRevertsWithUnauthorizedCaller() public {
        address tokenAddress = makeAddr("token");
        
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        factory.createTokenIdentity(tokenAddress, accessManager);
    }

    function testCreateIdentityWithZeroWallet() public {
        bytes32[] memory managementKeys = new bytes32[](0);
        
        vm.prank(admin);
        vm.expectRevert();
        factory.createIdentity(address(0), managementKeys);
    }

    function testCreateTokenIdentityWithZeroToken() public {
        vm.prank(admin);
        vm.expectRevert();
        factory.createTokenIdentity(address(0), accessManager);
    }

    function testCreateTokenIdentityWithZeroAccessManager() public {
        address tokenAddress = makeAddr("token");
        
        vm.prank(admin);
        vm.expectRevert();
        factory.createTokenIdentity(tokenAddress, address(0));
    }

    function testCreateIdentityDeterministicAddress() public {
        bytes32[] memory managementKeys = new bytes32[](0);
        
        address predictedAddress = factory.calculateWalletIdentityAddress(user, user);
        
        vm.prank(admin);
        address actualAddress = factory.createIdentity(user, managementKeys);
        
        assertEq(actualAddress, predictedAddress);
    }

    function testCreateTokenIdentityDeterministicAddress() public {
        address tokenAddress = makeAddr("token");
        
        address predictedAddress = factory.calculateTokenIdentityAddress(tokenAddress, accessManager);
        
        vm.prank(admin);
        address actualAddress = factory.createTokenIdentity(tokenAddress, accessManager);
        
        assertEq(actualAddress, predictedAddress);
    }

    function testCreateIdentityForSameWalletFails() public {
        bytes32[] memory managementKeys = new bytes32[](0);
        
        vm.prank(admin);
        factory.createIdentity(user, managementKeys);
        
        vm.prank(admin);
        vm.expectRevert();
        factory.createIdentity(user, managementKeys);
    }

    function testCreateTokenIdentityForSameTokenFails() public {
        address tokenAddress = makeAddr("token");
        
        vm.prank(admin);
        factory.createTokenIdentity(tokenAddress, accessManager);
        
        vm.prank(admin);
        vm.expectRevert();
        factory.createTokenIdentity(tokenAddress, accessManager);
    }

    function testCreateMultipleIdentitiesForDifferentWallets() public {
        address user2 = makeAddr("user2");
        bytes32[] memory managementKeys = new bytes32[](0);
        
        vm.prank(admin);
        address identity1 = factory.createIdentity(user, managementKeys);
        
        vm.prank(admin);
        address identity2 = factory.createIdentity(user2, managementKeys);
        
        assertTrue(identity1 != identity2);
        assertTrue(identity1 != address(0));
        assertTrue(identity2 != address(0));
        assertEq(factory.getIdentity(user), identity1);
        assertEq(factory.getIdentity(user2), identity2);
    }

    function testCreateMultipleTokenIdentitiesForDifferentTokens() public {
        address token1 = makeAddr("token1");
        address token2 = makeAddr("token2");
        
        vm.prank(admin);
        address identity1 = factory.createTokenIdentity(token1, accessManager);
        
        vm.prank(admin);
        address identity2 = factory.createTokenIdentity(token2, accessManager);
        
        assertTrue(identity1 != identity2);
        assertTrue(identity1 != address(0));
        assertTrue(identity2 != address(0));
        assertEq(factory.getTokenIdentity(token1), identity1);
        assertEq(factory.getTokenIdentity(token2), identity2);
    }

    function testCreateIdentityWithEmptyManagementKeys() public {
        bytes32[] memory managementKeys = new bytes32[](0);
        
        vm.prank(admin);
        address identity = factory.createIdentity(user, managementKeys);
        
        assertTrue(identity != address(0));
        assertEq(factory.getIdentity(user), identity);
    }

    function testGetIdentityReturnsZeroForNonExistentWallet() public {
        vm.prank(admin);
        
        assertEq(factory.getIdentity(user), address(0));
    }

    function testGetTokenIdentityReturnsZeroForNonExistentToken() public {
        vm.prank(admin);
        
        address tokenAddress = makeAddr("token");
        assertEq(factory.getTokenIdentity(tokenAddress), address(0));
    }

    function testCalculateWalletIdentityAddressReturnsPredictableAddress() public {
        vm.prank(admin);
        
        address predictedAddress1 = factory.calculateWalletIdentityAddress(user, user);
        address predictedAddress2 = factory.calculateWalletIdentityAddress(user, user);
        
        assertEq(predictedAddress1, predictedAddress2);
        assertTrue(predictedAddress1 != address(0));
    }

    function testCalculateTokenIdentityAddressReturnsPredictableAddress() public {
        vm.prank(admin);
        
        address tokenAddress = makeAddr("token");
        address predictedAddress1 = factory.calculateTokenIdentityAddress(tokenAddress, accessManager);
        address predictedAddress2 = factory.calculateTokenIdentityAddress(tokenAddress, accessManager);
        
        assertEq(predictedAddress1, predictedAddress2);
        assertTrue(predictedAddress1 != address(0));
    }

    function testFactoryIsValid() public view {
        assertTrue(address(factory) != address(0));
    }
}