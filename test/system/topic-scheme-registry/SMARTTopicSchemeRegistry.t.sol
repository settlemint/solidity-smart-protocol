// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { SystemUtils } from "../../utils/SystemUtils.sol";
import { IdentityUtils } from "../../utils/IdentityUtils.sol";
import { ISMARTTopicSchemeRegistry } from
    "../../../contracts/system/topic-scheme-registry/ISMARTTopicSchemeRegistry.sol";
import { SMARTTopicSchemeRegistryImplementation } from
    "../../../contracts/system/topic-scheme-registry/SMARTTopicSchemeRegistryImplementation.sol";
import { SMARTSystemRoles } from "../../../contracts/system/SMARTSystemRoles.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract SMARTTopicSchemeRegistryTest is Test {
    SystemUtils public systemUtils;
    IdentityUtils public identityUtils;
    ISMARTTopicSchemeRegistry public topicSchemeRegistry;

    address public admin = makeAddr("admin");
    address public registrar = makeAddr("registrar");
    address public user = makeAddr("user");

    // Test data
    uint256 public constant TOPIC_ID_1 = 1;
    uint256 public constant TOPIC_ID_2 = 2;
    uint256 public constant TOPIC_ID_3 = 3;
    string public constant SIGNATURE_1 = "string name,uint256 age";
    string public constant SIGNATURE_2 = "address wallet,bool verified";
    string public constant SIGNATURE_3 = "bytes32 hash,uint256 timestamp";
    string public constant UPDATED_SIGNATURE = "string updatedName,uint256 updatedAge";

    event TopicSchemeRegistered(address indexed sender, uint256 indexed topicId, string signature);
    event TopicSchemesBatchRegistered(address indexed sender, uint256[] topicIds, string[] signatures);
    event TopicSchemeUpdated(address indexed sender, uint256 indexed topicId, string oldSignature, string newSignature);
    event TopicSchemeRemoved(address indexed sender, uint256 indexed topicId);

    function setUp() public {
        systemUtils = new SystemUtils(admin);
        identityUtils = new IdentityUtils(
            admin, systemUtils.identityFactory(), systemUtils.identityRegistry(), systemUtils.trustedIssuersRegistry()
        );

        // Get the topic scheme registry from the system
        topicSchemeRegistry = ISMARTTopicSchemeRegistry(systemUtils.system().topicSchemeRegistryProxy());

        // Grant registrar role to test address
        vm.prank(admin);
        IAccessControl(address(topicSchemeRegistry)).grantRole(SMARTSystemRoles.REGISTRAR_ROLE, registrar);
    }

    function test_InitialState() public view {
        assertEq(topicSchemeRegistry.getTopicSchemeCount(), 0);
        assertEq(topicSchemeRegistry.getAllTopicIds().length, 0);
    }

    function test_RegisterTopicScheme_Success() public {
        vm.prank(registrar);
        vm.expectEmit(true, true, false, true);
        emit TopicSchemeRegistered(registrar, TOPIC_ID_1, SIGNATURE_1);

        topicSchemeRegistry.registerTopicScheme(TOPIC_ID_1, SIGNATURE_1);

        assertTrue(topicSchemeRegistry.hasTopicScheme(TOPIC_ID_1));
        assertEq(topicSchemeRegistry.getTopicSchemeSignature(TOPIC_ID_1), SIGNATURE_1);
        assertEq(topicSchemeRegistry.getTopicSchemeCount(), 1);

        ISMARTTopicSchemeRegistry.TopicScheme memory scheme = topicSchemeRegistry.getTopicScheme(TOPIC_ID_1);
        assertEq(scheme.topicId, TOPIC_ID_1);
        assertEq(scheme.signature, SIGNATURE_1);
        assertTrue(scheme.exists);
    }

    function test_RegisterTopicScheme_OnlyRegistrar() public {
        vm.prank(user);
        vm.expectRevert();
        topicSchemeRegistry.registerTopicScheme(TOPIC_ID_1, SIGNATURE_1);
    }

    function test_RegisterTopicScheme_InvalidTopicId() public {
        vm.prank(registrar);
        vm.expectRevert(abi.encodeWithSignature("InvalidTopicId()"));
        topicSchemeRegistry.registerTopicScheme(0, SIGNATURE_1);
    }

    function test_RegisterTopicScheme_EmptySignature() public {
        vm.prank(registrar);
        vm.expectRevert(abi.encodeWithSignature("EmptySignature()"));
        topicSchemeRegistry.registerTopicScheme(TOPIC_ID_1, "");
    }

    function test_RegisterTopicScheme_AlreadyExists() public {
        vm.prank(registrar);
        topicSchemeRegistry.registerTopicScheme(TOPIC_ID_1, SIGNATURE_1);

        vm.prank(registrar);
        vm.expectRevert(abi.encodeWithSignature("TopicSchemeAlreadyExists(uint256)", TOPIC_ID_1));
        topicSchemeRegistry.registerTopicScheme(TOPIC_ID_1, SIGNATURE_2);
    }

    function test_BatchRegisterTopicSchemes_Success() public {
        uint256[] memory topicIds = new uint256[](3);
        topicIds[0] = TOPIC_ID_1;
        topicIds[1] = TOPIC_ID_2;
        topicIds[2] = TOPIC_ID_3;

        string[] memory signatures = new string[](3);
        signatures[0] = SIGNATURE_1;
        signatures[1] = SIGNATURE_2;
        signatures[2] = SIGNATURE_3;

        vm.prank(registrar);
        vm.expectEmit(true, false, false, false);
        emit TopicSchemesBatchRegistered(registrar, topicIds, signatures);

        topicSchemeRegistry.batchRegisterTopicSchemes(topicIds, signatures);

        assertEq(topicSchemeRegistry.getTopicSchemeCount(), 3);
        assertTrue(topicSchemeRegistry.hasTopicScheme(TOPIC_ID_1));
        assertTrue(topicSchemeRegistry.hasTopicScheme(TOPIC_ID_2));
        assertTrue(topicSchemeRegistry.hasTopicScheme(TOPIC_ID_3));

        uint256[] memory allTopicIds = topicSchemeRegistry.getAllTopicIds();
        assertEq(allTopicIds.length, 3);
        assertEq(allTopicIds[0], TOPIC_ID_1);
        assertEq(allTopicIds[1], TOPIC_ID_2);
        assertEq(allTopicIds[2], TOPIC_ID_3);
    }

    function test_BatchRegisterTopicSchemes_EmptyArrays() public {
        uint256[] memory emptyTopicIds = new uint256[](0);
        string[] memory emptySignatures = new string[](0);

        vm.prank(registrar);
        vm.expectRevert(abi.encodeWithSignature("EmptyArraysProvided()"));
        topicSchemeRegistry.batchRegisterTopicSchemes(emptyTopicIds, emptySignatures);
    }

    function test_BatchRegisterTopicSchemes_ArrayLengthMismatch() public {
        uint256[] memory topicIds = new uint256[](2);
        topicIds[0] = TOPIC_ID_1;
        topicIds[1] = TOPIC_ID_2;

        string[] memory signatures = new string[](1);
        signatures[0] = SIGNATURE_1;

        vm.prank(registrar);
        vm.expectRevert(abi.encodeWithSignature("ArrayLengthMismatch(uint256,uint256)", 2, 1));
        topicSchemeRegistry.batchRegisterTopicSchemes(topicIds, signatures);
    }

    function test_UpdateTopicScheme_Success() public {
        // First register a topic scheme
        vm.prank(registrar);
        topicSchemeRegistry.registerTopicScheme(TOPIC_ID_1, SIGNATURE_1);

        // Then update it
        vm.prank(registrar);
        vm.expectEmit(true, true, false, true);
        emit TopicSchemeUpdated(registrar, TOPIC_ID_1, SIGNATURE_1, UPDATED_SIGNATURE);

        topicSchemeRegistry.updateTopicScheme(TOPIC_ID_1, UPDATED_SIGNATURE);

        assertEq(topicSchemeRegistry.getTopicSchemeSignature(TOPIC_ID_1), UPDATED_SIGNATURE);
    }

    function test_UpdateTopicScheme_DoesNotExist() public {
        vm.prank(registrar);
        vm.expectRevert(abi.encodeWithSignature("TopicSchemeDoesNotExist(uint256)", TOPIC_ID_1));
        topicSchemeRegistry.updateTopicScheme(TOPIC_ID_1, UPDATED_SIGNATURE);
    }

    function test_RemoveTopicScheme_Success() public {
        // First register a topic scheme
        vm.prank(registrar);
        topicSchemeRegistry.registerTopicScheme(TOPIC_ID_1, SIGNATURE_1);

        assertEq(topicSchemeRegistry.getTopicSchemeCount(), 1);
        assertTrue(topicSchemeRegistry.hasTopicScheme(TOPIC_ID_1));

        // Then remove it
        vm.prank(registrar);
        vm.expectEmit(true, true, false, false);
        emit TopicSchemeRemoved(registrar, TOPIC_ID_1);

        topicSchemeRegistry.removeTopicScheme(TOPIC_ID_1);

        assertEq(topicSchemeRegistry.getTopicSchemeCount(), 0);
        assertFalse(topicSchemeRegistry.hasTopicScheme(TOPIC_ID_1));
    }

    function test_RemoveTopicScheme_DoesNotExist() public {
        vm.prank(registrar);
        vm.expectRevert(abi.encodeWithSignature("TopicSchemeDoesNotExist(uint256)", TOPIC_ID_1));
        topicSchemeRegistry.removeTopicScheme(TOPIC_ID_1);
    }

    function test_GetAllTopicIds_MultipleSchemes() public {
        // Register multiple topic schemes
        vm.startPrank(registrar);
        topicSchemeRegistry.registerTopicScheme(TOPIC_ID_1, SIGNATURE_1);
        topicSchemeRegistry.registerTopicScheme(TOPIC_ID_2, SIGNATURE_2);
        topicSchemeRegistry.registerTopicScheme(TOPIC_ID_3, SIGNATURE_3);
        vm.stopPrank();

        uint256[] memory allTopicIds = topicSchemeRegistry.getAllTopicIds();
        assertEq(allTopicIds.length, 3);

        // Verify all topic IDs are present (order might vary)
        bool found1 = false;
        bool found2 = false;
        bool found3 = false;

        for (uint256 i = 0; i < allTopicIds.length; i++) {
            if (allTopicIds[i] == TOPIC_ID_1) found1 = true;
            if (allTopicIds[i] == TOPIC_ID_2) found2 = true;
            if (allTopicIds[i] == TOPIC_ID_3) found3 = true;
        }

        assertTrue(found1);
        assertTrue(found2);
        assertTrue(found3);
    }

    function test_SupportsInterface() public view {
        assertTrue(topicSchemeRegistry.supportsInterface(type(ISMARTTopicSchemeRegistry).interfaceId));
        assertTrue(topicSchemeRegistry.supportsInterface(type(IERC165).interfaceId));
        assertTrue(topicSchemeRegistry.supportsInterface(type(IAccessControl).interfaceId));
        assertFalse(topicSchemeRegistry.supportsInterface(bytes4(0xffffffff)));
    }

    function test_AccessControl() public view {
        IAccessControl accessControl = IAccessControl(address(topicSchemeRegistry));
        assertTrue(accessControl.hasRole(SMARTSystemRoles.DEFAULT_ADMIN_ROLE, admin));
        assertTrue(accessControl.hasRole(SMARTSystemRoles.REGISTRAR_ROLE, registrar));
        assertFalse(accessControl.hasRole(SMARTSystemRoles.REGISTRAR_ROLE, user));
    }

    function test_ComplexWorkflow() public {
        vm.startPrank(registrar);

        // 1. Register multiple topic schemes
        topicSchemeRegistry.registerTopicScheme(TOPIC_ID_1, SIGNATURE_1);
        topicSchemeRegistry.registerTopicScheme(TOPIC_ID_2, SIGNATURE_2);

        assertEq(topicSchemeRegistry.getTopicSchemeCount(), 2);

        // 2. Update one scheme
        topicSchemeRegistry.updateTopicScheme(TOPIC_ID_1, UPDATED_SIGNATURE);
        assertEq(topicSchemeRegistry.getTopicSchemeSignature(TOPIC_ID_1), UPDATED_SIGNATURE);

        // 3. Add more schemes via batch
        uint256[] memory newTopicIds = new uint256[](1);
        newTopicIds[0] = TOPIC_ID_3;
        string[] memory newSignatures = new string[](1);
        newSignatures[0] = SIGNATURE_3;

        topicSchemeRegistry.batchRegisterTopicSchemes(newTopicIds, newSignatures);
        assertEq(topicSchemeRegistry.getTopicSchemeCount(), 3);

        // 4. Remove one scheme
        topicSchemeRegistry.removeTopicScheme(TOPIC_ID_2);
        assertEq(topicSchemeRegistry.getTopicSchemeCount(), 2);
        assertFalse(topicSchemeRegistry.hasTopicScheme(TOPIC_ID_2));

        // 5. Verify remaining schemes
        assertTrue(topicSchemeRegistry.hasTopicScheme(TOPIC_ID_1));
        assertTrue(topicSchemeRegistry.hasTopicScheme(TOPIC_ID_3));

        vm.stopPrank();
    }

    function test_FuzzRegisterTopicScheme(uint256 topicId, string calldata signature) public {
        vm.assume(topicId > 0);
        vm.assume(bytes(signature).length > 0);
        vm.assume(bytes(signature).length <= 1000); // Reasonable limit

        vm.prank(registrar);
        topicSchemeRegistry.registerTopicScheme(topicId, signature);

        assertTrue(topicSchemeRegistry.hasTopicScheme(topicId));
        assertEq(topicSchemeRegistry.getTopicSchemeSignature(topicId), signature);
        assertEq(topicSchemeRegistry.getTopicSchemeCount(), 1);
    }
}
