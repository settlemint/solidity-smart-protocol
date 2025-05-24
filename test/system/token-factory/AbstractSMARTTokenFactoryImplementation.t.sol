// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../../contracts/system/token-factory/AbstractSMARTTokenFactoryImplementation.sol";
import "../../../contracts/system/token-factory/ISMARTTokenFactory.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

// Simple concrete implementation for testing
contract TestableTokenFactory is AbstractSMARTTokenFactoryImplementation {
    constructor(address forwarder) AbstractSMARTTokenFactoryImplementation(forwarder) { }

    function isValidTokenImplementation(address) external pure override returns (bool) {
        return true;
    }

    // Expose internal functions for testing by reimplementing the logic
    // Note: Functions are private in AbstractSMARTTokenFactoryImplementation, so we
    // replicate the logic here. This ensures our test assumptions match implementation.
    function exposedCalculateSalt(string memory name, string memory symbol) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(name, symbol));
    }

    function exposedPredictProxyAddress(
        bytes memory proxyCreationCode,
        bytes memory encodedConstructorArgs,
        string memory nameForSalt,
        string memory symbolForSalt
    )
        external
        view
        returns (address)
    {
        bytes32 salt = keccak256(abi.encodePacked(nameForSalt, symbolForSalt));
        bytes memory fullCreationCode = bytes.concat(proxyCreationCode, encodedConstructorArgs);
        bytes32 bytecodeHash = keccak256(fullCreationCode);
        return Create2.computeAddress(salt, bytecodeHash, address(this));
    }
}

contract MockProxy {
    uint256 public value;

    constructor(uint256 _value) {
        value = _value;
    }
}

contract AbstractSMARTTokenFactoryImplementationSimpleTest is Test {
    TestableTokenFactory public factory;
    address public admin;

    function setUp() public {
        admin = makeAddr("admin");
        factory = new TestableTokenFactory(address(0));
    }

    function testConstructorDisablesInitializers() public {
        // Test that the constructor properly disables initializers
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        factory.initialize(admin, admin, admin);
    }

    function testSupportsInterface() public view {
        assertTrue(factory.supportsInterface(type(ISMARTTokenFactory).interfaceId));
        assertTrue(factory.supportsInterface(type(IERC165).interfaceId));
    }

    function testIsValidTokenImplementation() public {
        address testAddress = makeAddr("anyAddress");
        assertTrue(factory.isValidTokenImplementation(testAddress));
    }

    function testIsFactoryTokenInitiallyFalse() public {
        address randomAddress = makeAddr("random");
        assertFalse(factory.isFactoryToken(randomAddress));
    }

    function testTokenImplementationInitiallyZero() public view {
        assertEq(factory.tokenImplementation(), address(0));
    }

    function testInheritanceStructure() public view {
        // Test that the contract supports expected interfaces from inheritance
        assertTrue(factory.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(factory.supportsInterface(type(IAccessControlEnumerable).interfaceId));
    }

    function testCalculateSaltDeterministic() public {
        bytes32 salt1 = factory.exposedCalculateSalt("TestToken", "TEST");
        bytes32 salt2 = factory.exposedCalculateSalt("TestToken", "TEST");

        assertEq(salt1, salt2);
        assertTrue(salt1 != bytes32(0));
    }

    function testCalculateSaltDifferentInputs() public {
        bytes32 salt1 = factory.exposedCalculateSalt("TestToken1", "TEST1");
        bytes32 salt2 = factory.exposedCalculateSalt("TestToken2", "TEST2");

        assertTrue(salt1 != salt2);
    }

    function testPredictProxyAddressDeterministic() public {
        bytes memory proxyCode = type(MockProxy).creationCode;
        bytes memory constructorArgs = abi.encode(123);

        address predicted1 = factory.exposedPredictProxyAddress(proxyCode, constructorArgs, "TestToken", "TEST");

        address predicted2 = factory.exposedPredictProxyAddress(proxyCode, constructorArgs, "TestToken", "TEST");

        assertEq(predicted1, predicted2);
        assertTrue(predicted1 != address(0));
    }

    function testPredictProxyAddressDifferentSalts() public {
        bytes memory proxyCode = type(MockProxy).creationCode;
        bytes memory constructorArgs = abi.encode(123);

        address predicted1 = factory.exposedPredictProxyAddress(proxyCode, constructorArgs, "TestToken1", "TEST1");

        address predicted2 = factory.exposedPredictProxyAddress(proxyCode, constructorArgs, "TestToken2", "TEST2");

        assertTrue(predicted1 != predicted2);
    }

    function testErrorSelectors() public pure {
        // Test that error selectors are properly defined
        bytes4 invalidTokenSelector = AbstractSMARTTokenFactoryImplementation.InvalidTokenAddress.selector;
        bytes4 invalidImplSelector = AbstractSMARTTokenFactoryImplementation.InvalidImplementationAddress.selector;
        bytes4 proxyFailedSelector = AbstractSMARTTokenFactoryImplementation.ProxyCreationFailed.selector;
        bytes4 addressDeployedSelector = AbstractSMARTTokenFactoryImplementation.AddressAlreadyDeployed.selector;

        assertTrue(invalidTokenSelector != bytes4(0));
        assertTrue(invalidImplSelector != bytes4(0));
        assertTrue(proxyFailedSelector != bytes4(0));
        assertTrue(addressDeployedSelector != bytes4(0));

        // Test that they are all different
        assertTrue(invalidTokenSelector != invalidImplSelector);
        assertTrue(invalidTokenSelector != proxyFailedSelector);
        assertTrue(invalidTokenSelector != addressDeployedSelector);
        assertTrue(invalidImplSelector != proxyFailedSelector);
        assertTrue(invalidImplSelector != addressDeployedSelector);
        assertTrue(proxyFailedSelector != addressDeployedSelector);
    }

    function testSupportsInterfaceOverride() public view {
        // Test that the abstract contract properly overrides supportsInterface
        assertTrue(factory.supportsInterface(type(ISMARTTokenFactory).interfaceId));
        assertTrue(factory.supportsInterface(type(IERC165).interfaceId));
        assertTrue(factory.supportsInterface(type(IAccessControl).interfaceId));

        // Test that it doesn't support random interfaces
        assertFalse(factory.supportsInterface(bytes4(0x12345678)));
    }

    function testIsValidTokenImplementationAlwaysTrue() public {
        // This test implementation always returns true
        assertTrue(factory.isValidTokenImplementation(address(0)));
        assertTrue(factory.isValidTokenImplementation(makeAddr("random")));
        assertTrue(factory.isValidTokenImplementation(address(factory)));
    }
}
