// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { AbstractSMARTAssetTest } from "./AbstractSMARTAssetTest.sol";
import { TestConstants } from "../Constants.sol";
import { SMARTComplianceModuleParamPair } from "../../contracts/interface/structs/SMARTComplianceModuleParamPair.sol";
import { ISMARTTokenSale } from "../../contracts/interface/ISMARTTokenSale.sol";
import { SMARTTokenSale } from "../../contracts/extensions/token-sale/SMARTTokenSale.sol";
import { SMARTTokenSaleFactory } from "../../contracts/extensions/token-sale/SMARTTokenSaleFactory.sol";
import { SMARTToken } from "../examples/SMARTToken.sol";
import { ISMARTTokenAccessManager } from "../../contracts/extensions/access-managed/ISMARTTokenAccessManager.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { SMARTTopics } from "../../contracts/system/SMARTTopics.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SMARTTokenSaleFactoryTest is AbstractSMARTAssetTest {
    SMARTTokenSale public tokenSaleImplementation;
    SMARTTokenSaleFactory public tokenSaleFactory;
    SMARTToken public smartToken;

    address public owner;
    address public deployer;
    address public saleAdmin;
    address public nonAuthorized;

    // Sale parameters
    uint256 public saleStart;
    uint256 public saleDuration = 30 days;
    uint256 public hardCap = 1000 * 10 ** 18;
    uint256 public basePrice = 1 ether;

    // Events to test
    event TokenSaleDeployed(address indexed tokenSaleAddress, address indexed tokenAddress, address indexed saleAdmin);
    event ImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);

    function setUp() public {
        // Create test accounts
        owner = makeAddr("owner");
        deployer = makeAddr("deployer");
        saleAdmin = makeAddr("saleAdmin");
        nonAuthorized = makeAddr("nonAuthorized");

        // Initialize SMART system
        setUpSMART(owner);

        // Set up identities
        _setUpIdentity(owner, "Owner");
        _setUpIdentity(deployer, "Deployer");
        _setUpIdentity(saleAdmin, "Sale Admin");

        // Create access manager for the token
        address[] memory initialAdmins = new address[](1);
        initialAdmins[0] = owner;
        ISMARTTokenAccessManager accessManager = systemUtils.createTokenAccessManager(initialAdmins);

        // Deploy SMART token
        vm.prank(owner);
        smartToken = new SMARTToken(
            "Test SMART Token",
            "TST",
            18,
            address(0), // onchainID
            address(systemUtils.identityRegistry()),
            address(systemUtils.compliance()),
            new uint256[](0), // requiredClaimTopics
            new SMARTComplianceModuleParamPair[](0), // initialModulePairs
            systemUtils.topicSchemeRegistry().getTopicId(SMARTTopics.TOPIC_COLLATERAL),
            address(accessManager)
        );

        // Grant necessary roles to owner for token operations
        _grantAllRoles(address(accessManager), owner, owner);

        // Deploy contracts
        tokenSaleImplementation = new SMARTTokenSale(address(forwarder));
        SMARTTokenSaleFactory tokenSaleFactoryImpl = new SMARTTokenSaleFactory(address(forwarder));

        // Deploy factory through proxy pattern with owner as caller
        vm.startPrank(owner);
        ERC1967Proxy factoryProxy = new ERC1967Proxy(
            address(tokenSaleFactoryImpl),
            abi.encodeCall(tokenSaleFactoryImpl.initialize, (address(tokenSaleImplementation)))
        );
        tokenSaleFactory = SMARTTokenSaleFactory(address(factoryProxy));

        // Grant deployer role
        tokenSaleFactory.grantRole(tokenSaleFactory.DEPLOYER_ROLE(), deployer);
        vm.stopPrank();

        // Set sale start time
        saleStart = block.timestamp + 1 hours;
    }

    // --- Initialization Tests ---

    function test_Initialize() public {
        assertEq(tokenSaleFactory.implementation(), address(tokenSaleImplementation));
        assertTrue(tokenSaleFactory.hasRole(tokenSaleFactory.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(tokenSaleFactory.hasRole(tokenSaleFactory.DEPLOYER_ROLE(), owner));
        assertTrue(tokenSaleFactory.hasRole(tokenSaleFactory.DEPLOYER_ROLE(), deployer));
    }

    function test_RevertInitializeInvalidImplementation() public {
        SMARTTokenSaleFactory newFactoryImpl = new SMARTTokenSaleFactory(address(forwarder));

        vm.expectRevert("Invalid implementation");
        new ERC1967Proxy(address(newFactoryImpl), abi.encodeCall(newFactoryImpl.initialize, (address(0))));
    }

    // --- Implementation Management Tests ---

    function test_UpdateImplementation() public {
        SMARTTokenSale newImplementation = new SMARTTokenSale(address(forwarder));

        vm.expectEmit(true, true, false, false);
        emit ImplementationUpdated(address(tokenSaleImplementation), address(newImplementation));

        vm.prank(owner);
        tokenSaleFactory.updateImplementation(address(newImplementation));

        assertEq(tokenSaleFactory.implementation(), address(newImplementation));
    }

    function test_RevertUpdateImplementationUnauthorized() public {
        SMARTTokenSale newImplementation = new SMARTTokenSale(address(forwarder));

        vm.expectRevert();
        vm.prank(nonAuthorized);
        tokenSaleFactory.updateImplementation(address(newImplementation));
    }

    function test_RevertUpdateImplementationInvalid() public {
        vm.expectRevert("Invalid implementation");
        vm.prank(owner);
        tokenSaleFactory.updateImplementation(address(0));
    }

    // --- Token Sale Deployment Tests ---

    function test_DeployTokenSale() public {
        vm.expectEmit(false, true, true, false);
        emit TokenSaleDeployed(address(0), address(smartToken), saleAdmin);

        vm.prank(deployer);
        address saleAddress = tokenSaleFactory.deployTokenSale(
            address(smartToken), saleAdmin, saleStart, saleDuration, hardCap, basePrice, block.timestamp
        );

        // Verify the sale was deployed correctly
        assertTrue(saleAddress != address(0));
        assertTrue(tokenSaleFactory.isTokenSale(saleAddress));

        ISMARTTokenSale tokenSale = ISMARTTokenSale(saleAddress);

        // Verify sale parameters
        (uint256 soldAmount, uint256 remainingTokens, uint256 startTime, uint256 endTime) = tokenSale.getSaleInfo();
        assertEq(soldAmount, 0);
        assertEq(remainingTokens, hardCap);
        assertEq(startTime, saleStart);
        assertEq(endTime, saleStart + saleDuration);

        // Verify roles were granted
        SMARTTokenSale concreteSale = SMARTTokenSale(saleAddress);
        assertTrue(IAccessControl(saleAddress).hasRole(concreteSale.SALE_ADMIN_ROLE(), saleAdmin));
        assertTrue(IAccessControl(saleAddress).hasRole(concreteSale.FUNDS_MANAGER_ROLE(), saleAdmin));
    }

    function test_DeployMultipleTokenSales() public {
        // Deploy first sale
        vm.prank(deployer);
        address sale1 = tokenSaleFactory.deployTokenSale(
            address(smartToken),
            saleAdmin,
            saleStart,
            saleDuration,
            hardCap,
            basePrice,
            1 // saltNonce
        );

        // Deploy second sale with different parameters
        vm.prank(deployer);
        address sale2 = tokenSaleFactory.deployTokenSale(
            address(smartToken),
            saleAdmin,
            saleStart + 1 days,
            saleDuration,
            hardCap / 2,
            basePrice * 2,
            2 // saltNonce
        );

        assertTrue(sale1 != sale2);
        assertTrue(tokenSaleFactory.isTokenSale(sale1));
        assertTrue(tokenSaleFactory.isTokenSale(sale2));
    }

    function test_RevertDeployTokenSaleUnauthorized() public {
        vm.expectRevert();
        vm.prank(nonAuthorized);
        tokenSaleFactory.deployTokenSale(
            address(smartToken), saleAdmin, saleStart, saleDuration, hardCap, basePrice, block.timestamp
        );
    }

    function test_RevertDeployTokenSaleInvalidToken() public {
        vm.expectRevert("Invalid token address");
        vm.prank(deployer);
        tokenSaleFactory.deployTokenSale(
            address(0), // Invalid token
            saleAdmin,
            saleStart,
            saleDuration,
            hardCap,
            basePrice,
            block.timestamp
        );
    }

    function test_RevertDeployTokenSaleInvalidAdmin() public {
        vm.expectRevert("Invalid admin address");
        vm.prank(deployer);
        tokenSaleFactory.deployTokenSale(
            address(smartToken),
            address(0), // Invalid admin
            saleStart,
            saleDuration,
            hardCap,
            basePrice,
            block.timestamp
        );
    }

    function test_RevertDeployTokenSaleInvalidStartTime() public {
        vm.expectRevert("Sale start must be in the future");
        vm.prank(deployer);
        tokenSaleFactory.deployTokenSale(
            address(smartToken),
            saleAdmin,
            block.timestamp - 1, // Past time
            saleDuration,
            hardCap,
            basePrice,
            block.timestamp
        );
    }

    function test_RevertDeployTokenSaleInvalidDuration() public {
        vm.expectRevert("Sale duration must be positive");
        vm.prank(deployer);
        tokenSaleFactory.deployTokenSale(
            address(smartToken),
            saleAdmin,
            saleStart,
            0, // Zero duration
            hardCap,
            basePrice,
            block.timestamp
        );
    }

    function test_RevertDeployTokenSaleInvalidHardCap() public {
        vm.expectRevert("Hard cap must be positive");
        vm.prank(deployer);
        tokenSaleFactory.deployTokenSale(
            address(smartToken),
            saleAdmin,
            saleStart,
            saleDuration,
            0, // Zero hard cap
            basePrice,
            block.timestamp
        );
    }

    function test_RevertDeployTokenSaleInvalidBasePrice() public {
        vm.expectRevert("Base price must be positive");
        vm.prank(deployer);
        tokenSaleFactory.deployTokenSale(
            address(smartToken),
            saleAdmin,
            saleStart,
            saleDuration,
            hardCap,
            0, // Zero base price
            block.timestamp
        );
    }

    // --- Integration Tests ---

    function test_DeployAndConfigureSale() public {
        // Deploy sale
        vm.prank(deployer);
        address saleAddress = tokenSaleFactory.deployTokenSale(
            address(smartToken), saleAdmin, saleStart, saleDuration, hardCap, basePrice, block.timestamp
        );

        ISMARTTokenSale tokenSale = ISMARTTokenSale(saleAddress);

        // Configure sale as admin
        vm.startPrank(saleAdmin);

        // Set purchase limits
        tokenSale.setPurchaseLimits(1 * 10 ** 18, 100 * 10 ** 18);

        // Configure vesting
        tokenSale.configureVesting(saleStart + saleDuration + 1 days, 365 days, 90 days);

        vm.stopPrank();

        // Verify configuration worked
        assertEq(tokenSale.saleStatus(), 0); // SETUP status
    }

    function test_FactoryTrackingState() public {
        // Deploy sale
        vm.prank(deployer);
        address saleAddress = tokenSaleFactory.deployTokenSale(
            address(smartToken), saleAdmin, saleStart, saleDuration, hardCap, basePrice, block.timestamp
        );

        // Verify tracking
        assertTrue(tokenSaleFactory.isTokenSale(saleAddress));
        assertFalse(tokenSaleFactory.isTokenSale(address(smartToken))); // Not a sale
        assertFalse(tokenSaleFactory.isTokenSale(makeAddr("random"))); // Random address
    }
}
