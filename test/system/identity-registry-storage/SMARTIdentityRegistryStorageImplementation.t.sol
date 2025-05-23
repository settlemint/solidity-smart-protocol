// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {SMARTIdentityRegistryStorageImplementation} from "../../../contracts/system/identity-registry-storage/SMARTIdentityRegistryStorageImplementation.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC3643IdentityRegistryStorage} from "../../../contracts/interface/ERC-3643/IERC3643IdentityRegistryStorage.sol";
import {IIdentity} from "@onchainid/contracts/interface/IIdentity.sol";
import {SystemUtils} from "../../utils/SystemUtils.sol";
import {IdentityUtils} from "../../utils/IdentityUtils.sol";
import {SMARTSystemRoles} from "../../../contracts/system/SMARTSystemRoles.sol";

contract SMARTIdentityRegistryStorageImplementationTest is Test {
    SMARTIdentityRegistryStorageImplementation public implementation;
    SMARTIdentityRegistryStorageImplementation public storageContract;
    SystemUtils public systemUtils;
    IdentityUtils public identityUtils;

    address public admin;
    address public system;
    address public forwarder;
    address public user1;
    address public user2;
    address public registry1;
    address public registry2;
    
    IIdentity public identity1;
    IIdentity public identity2;
    uint16 public constant COUNTRY_US = 840;
    uint16 public constant COUNTRY_UK = 826;

    event IdentityStored(address indexed investorAddress, IIdentity indexed identity);
    event IdentityUnstored(address indexed investorAddress, IIdentity indexed identity);
    event IdentityModified(IIdentity indexed oldIdentity, IIdentity indexed newIdentity);
    event CountryModified(address indexed _identityWallet, uint16 _country);
    event IdentityRegistryBound(address indexed identityRegistry);
    event IdentityRegistryUnbound(address indexed identityRegistry);

    function setUp() public {
        admin = makeAddr("admin");
        system = makeAddr("system");
        forwarder = makeAddr("forwarder");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        registry1 = makeAddr("registry1");
        registry2 = makeAddr("registry2");

        systemUtils = new SystemUtils(admin);
        identityUtils = new IdentityUtils(
            admin,
            systemUtils.identityFactory(),
            systemUtils.identityRegistry(),
            systemUtils.trustedIssuersRegistry()
        );

        implementation = new SMARTIdentityRegistryStorageImplementation(forwarder);
        
        bytes memory initData = abi.encodeWithSelector(
            SMARTIdentityRegistryStorageImplementation.initialize.selector,
            system,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        storageContract = SMARTIdentityRegistryStorageImplementation(address(proxy));

        identity1 = IIdentity(identityUtils.createIdentity(user1));
        identity2 = IIdentity(identityUtils.createIdentity(user2));
    }

    function test_Constructor() public {
        SMARTIdentityRegistryStorageImplementation impl = new SMARTIdentityRegistryStorageImplementation(forwarder);
        assertEq(impl.isTrustedForwarder(forwarder), true);
    }

    function test_Initialize() public {
        assertTrue(storageContract.hasRole(SMARTSystemRoles.DEFAULT_ADMIN_ROLE, admin));
        assertTrue(storageContract.hasRole(SMARTSystemRoles.STORAGE_MODIFIER_ROLE, admin));
        assertTrue(storageContract.hasRole(SMARTSystemRoles.MANAGE_REGISTRIES_ROLE, system));
        assertEq(storageContract.getRoleAdmin(SMARTSystemRoles.STORAGE_MODIFIER_ROLE), SMARTSystemRoles.MANAGE_REGISTRIES_ROLE);
    }

    function test_InitializeTwice_ShouldRevert() public {
        vm.expectRevert();
        storageContract.initialize(system, admin);
    }

    function test_AddIdentityToStorage() public {
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit IdentityStored(user1, identity1);
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);

        assertEq(address(storageContract.storedIdentity(user1)), address(identity1));
        assertEq(storageContract.storedInvestorCountry(user1), COUNTRY_US);
        
        address[] memory wallets = storageContract.getIdentityWallets();
        assertEq(wallets.length, 1);
        assertEq(wallets[0], user1);
    }

    function test_AddIdentityToStorage_InvalidWalletAddress_ShouldRevert() public {
        vm.prank(admin);
        vm.expectRevert();
        storageContract.addIdentityToStorage(address(0), identity1, COUNTRY_US);
    }

    function test_AddIdentityToStorage_InvalidIdentityAddress_ShouldRevert() public {
        vm.prank(admin);
        vm.expectRevert();
        storageContract.addIdentityToStorage(user1, IIdentity(address(0)), COUNTRY_US);
    }

    function test_AddIdentityToStorage_IdentityAlreadyExists_ShouldRevert() public {
        vm.startPrank(admin);
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);
        
        vm.expectRevert();
        storageContract.addIdentityToStorage(user1, identity2, COUNTRY_UK);
        vm.stopPrank();
    }

    function test_AddIdentityToStorage_UnauthorizedCaller_ShouldRevert() public {
        vm.prank(user1);
        vm.expectRevert();
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);
    }

    function test_RemoveIdentityFromStorage() public {
        vm.startPrank(admin);
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);
        storageContract.addIdentityToStorage(user2, identity2, COUNTRY_UK);
        
        vm.expectEmit(true, true, false, true);
        emit IdentityUnstored(user1, identity1);
        storageContract.removeIdentityFromStorage(user1);
        vm.stopPrank();

        vm.expectRevert();
        storageContract.storedIdentity(user1);
        
        assertEq(address(storageContract.storedIdentity(user2)), address(identity2));
        
        address[] memory wallets = storageContract.getIdentityWallets();
        assertEq(wallets.length, 1);
        assertEq(wallets[0], user2);
    }

    function test_RemoveIdentityFromStorage_IdentityDoesNotExist_ShouldRevert() public {
        vm.prank(admin);
        vm.expectRevert();
        storageContract.removeIdentityFromStorage(user1);
    }

    function test_RemoveIdentityFromStorage_UnauthorizedCaller_ShouldRevert() public {
        vm.prank(admin);
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);
        
        vm.prank(user1);
        vm.expectRevert();
        storageContract.removeIdentityFromStorage(user1);
    }

    function test_ModifyStoredIdentity() public {
        vm.startPrank(admin);
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);
        
        vm.expectEmit(true, true, false, true);
        emit IdentityModified(identity1, identity2);
        storageContract.modifyStoredIdentity(user1, identity2);
        vm.stopPrank();

        assertEq(address(storageContract.storedIdentity(user1)), address(identity2));
        assertEq(storageContract.storedInvestorCountry(user1), COUNTRY_US);
    }

    function test_ModifyStoredIdentity_IdentityDoesNotExist_ShouldRevert() public {
        vm.prank(admin);
        vm.expectRevert();
        storageContract.modifyStoredIdentity(user1, identity2);
    }

    function test_ModifyStoredIdentity_InvalidIdentityAddress_ShouldRevert() public {
        vm.startPrank(admin);
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);
        
        vm.expectRevert();
        storageContract.modifyStoredIdentity(user1, IIdentity(address(0)));
        vm.stopPrank();
    }

    function test_ModifyStoredIdentity_UnauthorizedCaller_ShouldRevert() public {
        vm.prank(admin);
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);
        
        vm.prank(user1);
        vm.expectRevert();
        storageContract.modifyStoredIdentity(user1, identity2);
    }

    function test_ModifyStoredInvestorCountry() public {
        vm.startPrank(admin);
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);
        
        vm.expectEmit(true, true, false, true);
        emit CountryModified(user1, COUNTRY_UK);
        storageContract.modifyStoredInvestorCountry(user1, COUNTRY_UK);
        vm.stopPrank();

        assertEq(storageContract.storedInvestorCountry(user1), COUNTRY_UK);
        assertEq(address(storageContract.storedIdentity(user1)), address(identity1));
    }

    function test_ModifyStoredInvestorCountry_IdentityDoesNotExist_ShouldRevert() public {
        vm.prank(admin);
        vm.expectRevert();
        storageContract.modifyStoredInvestorCountry(user1, COUNTRY_UK);
    }

    function test_ModifyStoredInvestorCountry_UnauthorizedCaller_ShouldRevert() public {
        vm.prank(admin);
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);
        
        vm.prank(user1);
        vm.expectRevert();
        storageContract.modifyStoredInvestorCountry(user1, COUNTRY_UK);
    }

    function test_BindIdentityRegistry() public {
        vm.prank(system);
        vm.expectEmit(true, false, false, true);
        emit IdentityRegistryBound(registry1);
        storageContract.bindIdentityRegistry(registry1);

        assertTrue(storageContract.hasRole(SMARTSystemRoles.STORAGE_MODIFIER_ROLE, registry1));
        
        address[] memory linkedRegistries = storageContract.linkedIdentityRegistries();
        assertEq(linkedRegistries.length, 1);
        assertEq(linkedRegistries[0], registry1);
    }

    function test_BindIdentityRegistry_InvalidAddress_ShouldRevert() public {
        vm.prank(system);
        vm.expectRevert();
        storageContract.bindIdentityRegistry(address(0));
    }

    function test_BindIdentityRegistry_AlreadyBound_ShouldRevert() public {
        vm.startPrank(system);
        storageContract.bindIdentityRegistry(registry1);
        
        vm.expectRevert();
        storageContract.bindIdentityRegistry(registry1);
        vm.stopPrank();
    }

    function test_BindIdentityRegistry_UnauthorizedCaller_ShouldRevert() public {
        vm.prank(user1);
        vm.expectRevert();
        storageContract.bindIdentityRegistry(registry1);
    }

    function test_UnbindIdentityRegistry() public {
        vm.startPrank(system);
        storageContract.bindIdentityRegistry(registry1);
        storageContract.bindIdentityRegistry(registry2);
        
        vm.expectEmit(true, false, false, true);
        emit IdentityRegistryUnbound(registry1);
        storageContract.unbindIdentityRegistry(registry1);
        vm.stopPrank();

        assertFalse(storageContract.hasRole(SMARTSystemRoles.STORAGE_MODIFIER_ROLE, registry1));
        assertTrue(storageContract.hasRole(SMARTSystemRoles.STORAGE_MODIFIER_ROLE, registry2));
        
        address[] memory linkedRegistries = storageContract.linkedIdentityRegistries();
        assertEq(linkedRegistries.length, 1);
        assertEq(linkedRegistries[0], registry2);
    }

    function test_UnbindIdentityRegistry_NotBound_ShouldRevert() public {
        vm.prank(system);
        vm.expectRevert();
        storageContract.unbindIdentityRegistry(registry1);
    }

    function test_UnbindIdentityRegistry_UnauthorizedCaller_ShouldRevert() public {
        vm.prank(system);
        storageContract.bindIdentityRegistry(registry1);
        
        vm.prank(user1);
        vm.expectRevert();
        storageContract.unbindIdentityRegistry(registry1);
    }

    function test_StoredIdentity_IdentityDoesNotExist_ShouldRevert() public {
        vm.expectRevert();
        storageContract.storedIdentity(user1);
    }

    function test_StoredInvestorCountry_IdentityDoesNotExist_ShouldRevert() public {
        vm.expectRevert();
        storageContract.storedInvestorCountry(user1);
    }

    function test_GetIdentityWallets_EmptyArray() public {
        address[] memory wallets = storageContract.getIdentityWallets();
        assertEq(wallets.length, 0);
    }

    function test_LinkedIdentityRegistries_EmptyArray() public {
        address[] memory linkedRegistries = storageContract.linkedIdentityRegistries();
        assertEq(linkedRegistries.length, 0);
    }

    function test_SupportsInterface() public {
        assertTrue(storageContract.supportsInterface(type(IERC3643IdentityRegistryStorage).interfaceId));
        assertTrue(storageContract.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(storageContract.supportsInterface(type(IERC165).interfaceId));
        assertFalse(storageContract.supportsInterface(bytes4(0x12345678)));
    }

    function test_RegistryCanModifyStorage() public {
        vm.prank(system);
        storageContract.bindIdentityRegistry(registry1);
        
        vm.prank(registry1);
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);
        
        assertEq(address(storageContract.storedIdentity(user1)), address(identity1));
    }

    function test_MultipleIdentityWalletsOrder() public {
        vm.startPrank(admin);
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);
        storageContract.addIdentityToStorage(user2, identity2, COUNTRY_UK);
        vm.stopPrank();

        address[] memory wallets = storageContract.getIdentityWallets();
        assertEq(wallets.length, 2);
        assertEq(wallets[0], user1);
        assertEq(wallets[1], user2);

        vm.prank(admin);
        storageContract.removeIdentityFromStorage(user1);

        wallets = storageContract.getIdentityWallets();
        assertEq(wallets.length, 1);
        assertEq(wallets[0], user2);
    }

    function test_MultipleRegistriesOrder() public {
        vm.startPrank(system);
        storageContract.bindIdentityRegistry(registry1);
        storageContract.bindIdentityRegistry(registry2);
        vm.stopPrank();

        address[] memory linkedRegistries = storageContract.linkedIdentityRegistries();
        assertEq(linkedRegistries.length, 2);
        assertEq(linkedRegistries[0], registry1);
        assertEq(linkedRegistries[1], registry2);

        vm.prank(system);
        storageContract.unbindIdentityRegistry(registry1);

        linkedRegistries = storageContract.linkedIdentityRegistries();
        assertEq(linkedRegistries.length, 1);
        assertEq(linkedRegistries[0], registry2);
    }

    function test_RemoveLastIdentityFromArray() public {
        vm.startPrank(admin);
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);
        
        storageContract.removeIdentityFromStorage(user1);
        vm.stopPrank();

        address[] memory wallets = storageContract.getIdentityWallets();
        assertEq(wallets.length, 0);
    }

    function test_UnbindLastRegistryFromArray() public {
        vm.startPrank(system);
        storageContract.bindIdentityRegistry(registry1);
        
        storageContract.unbindIdentityRegistry(registry1);
        vm.stopPrank();

        address[] memory linkedRegistries = storageContract.linkedIdentityRegistries();
        assertEq(linkedRegistries.length, 0);
    }

    function test_TrustedForwarder() public {
        assertTrue(implementation.isTrustedForwarder(forwarder));
        assertFalse(implementation.isTrustedForwarder(user1));
    }

    function test_ZeroAddressTrustedForwarder() public {
        SMARTIdentityRegistryStorageImplementation impl = new SMARTIdentityRegistryStorageImplementation(address(0));
        assertTrue(impl.isTrustedForwarder(address(0)));
        assertFalse(impl.isTrustedForwarder(forwarder));
    }

    function test_EndToEndWorkflow() public {
        vm.prank(system);
        storageContract.bindIdentityRegistry(registry1);

        vm.prank(registry1);
        storageContract.addIdentityToStorage(user1, identity1, COUNTRY_US);

        assertEq(address(storageContract.storedIdentity(user1)), address(identity1));
        assertEq(storageContract.storedInvestorCountry(user1), COUNTRY_US);

        vm.prank(registry1);
        storageContract.modifyStoredIdentity(user1, identity2);

        assertEq(address(storageContract.storedIdentity(user1)), address(identity2));

        vm.prank(registry1);
        storageContract.modifyStoredInvestorCountry(user1, COUNTRY_UK);

        assertEq(storageContract.storedInvestorCountry(user1), COUNTRY_UK);

        vm.prank(registry1);
        storageContract.removeIdentityFromStorage(user1);

        vm.expectRevert();
        storageContract.storedIdentity(user1);

        vm.prank(system);
        storageContract.unbindIdentityRegistry(registry1);

        assertFalse(storageContract.hasRole(SMARTSystemRoles.STORAGE_MODIFIER_ROLE, registry1));
    }
}