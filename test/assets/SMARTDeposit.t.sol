// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { AbstractSMARTAssetTest } from "./AbstractSMARTAssetTest.sol";

import { ClaimUtils } from "../utils/ClaimUtils.sol";
import { ISMARTDeposit } from "../../contracts/assets/deposit/ISMARTDeposit.sol";
import { ISMARTDepositFactory } from "../../contracts/assets/deposit/ISMARTDepositFactory.sol";
import { SMARTDepositFactoryImplementation } from "../../contracts/assets/deposit/SMARTDepositFactoryImplementation.sol";
import { SMARTDepositImplementation } from "../../contracts/assets/deposit/SMARTDepositImplementation.sol";
import { SMARTTopics } from "../../contracts/assets/SMARTTopics.sol";
import { SMARTRoles } from "../../contracts/assets/SMARTRoles.sol";
import { SMARTSystemRoles } from "../../contracts/system/SMARTSystemRoles.sol";
import { InvalidDecimals } from "../../contracts/extensions/core/SMARTErrors.sol";
import { SMARTComplianceModuleParamPair } from "../../contracts/interface/structs/SMARTComplianceModuleParamPair.sol";
import { InsufficientCollateral } from "../../contracts/extensions/collateral/SMARTCollateralErrors.sol";
import { console } from "forge-std/console.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ISMARTTokenAccessManager } from "../../contracts/extensions/access-managed/ISMARTTokenAccessManager.sol";
import { MockedERC20Token } from "../utils/mocks/MockedERC20Token.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract SMARTDepositTest is AbstractSMARTAssetTest {
    ISMARTDepositFactory public depositFactory;
    ISMARTDeposit public deposit;

    address public owner;
    address public user1;
    address public user2;
    address public spender;

    uint8 public constant DECIMALS = 8;
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** DECIMALS;
    uint48 public constant COLLATERAL_LIVENESS = 7 days;

    function setUp() public {
        // Create identities
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        spender = makeAddr("spender");

        // Initialize SMART
        setUpSMART(owner);

        // Set up the Deposit Factory
        SMARTDepositFactoryImplementation depositFactoryImpl = new SMARTDepositFactoryImplementation(address(forwarder));
        SMARTDepositImplementation depositImpl = new SMARTDepositImplementation(address(forwarder));

        vm.startPrank(platformAdmin);
        depositFactory = ISMARTDepositFactory(
            systemUtils.system().createTokenFactory("Deposit", address(depositFactoryImpl), address(depositImpl))
        );

        // Grant registrar role to owner so that he can create the deposit
        IAccessControl(address(depositFactory)).grantRole(SMARTSystemRoles.TOKEN_DEPLOYER_ROLE, owner);
        vm.stopPrank();

        // Initialize identities
        _setUpIdentity(owner, "Owner");
        _setUpIdentity(user1, "User1");
        _setUpIdentity(user2, "User2");
        _setUpIdentity(spender, "Spender");

        deposit = _createDeposit("Deposit", "DEP", DECIMALS, new uint256[](0), new SMARTComplianceModuleParamPair[](0));
        vm.label(address(deposit), "Deposit");
    }

    function _createDeposit(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256[] memory requiredClaimTopics,
        SMARTComplianceModuleParamPair[] memory initialModulePairs
    )
        internal
        returns (ISMARTDeposit result)
    {
        vm.startPrank(owner);

        address depositAddress =
            depositFactory.createDeposit(name, symbol, decimals, requiredClaimTopics, initialModulePairs);
        result = ISMARTDeposit(depositAddress);

        vm.label(depositAddress, "Deposit");
        vm.stopPrank();

        _grantAllRoles(result.accessManager(), owner, owner);

        return result;
    }

    function _updateCollateral(address token, address tokenIssuer, uint256 collateralAmount) internal {
        // Use a very large amount and a long expiry
        uint256 farFutureExpiry = block.timestamp + 3650 days; // ~10 years

        vm.startPrank(tokenIssuer);
        _issueCollateralClaim(address(token), tokenIssuer, collateralAmount, farFutureExpiry);
        vm.stopPrank();
    }

    function _mintInitialSupply(address recipient) internal {
        _updateCollateral(address(deposit), owner, INITIAL_SUPPLY);
        vm.prank(owner);
        deposit.mint(recipient, INITIAL_SUPPLY);
    }

    function test_InitialState() public view {
        assertEq(deposit.name(), "Deposit");
        assertEq(deposit.symbol(), "DEP");
        assertEq(deposit.decimals(), DECIMALS);
        assertEq(deposit.totalSupply(), 0);
        assertTrue(deposit.hasRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, owner));
        assertTrue(deposit.hasRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE, owner));
        assertTrue(deposit.hasRole(SMARTRoles.CUSTODIAN_ROLE, owner));
        assertTrue(deposit.hasRole(SMARTRoles.EMERGENCY_ROLE, owner));
    }

    function test_DifferentDecimals() public {
        uint8[] memory decimalValues = new uint8[](3);
        decimalValues[0] = 0; // Test zero decimals
        decimalValues[1] = 6;
        decimalValues[2] = 8; // Test max decimals

        for (uint256 i = 0; i < decimalValues.length; ++i) {
            ISMARTDeposit newToken = _createDeposit(
                string.concat("Deposit ", Strings.toString(decimalValues[i])),
                string.concat("DEP_", Strings.toString(decimalValues[i])),
                decimalValues[i],
                new uint256[](0),
                new SMARTComplianceModuleParamPair[](0)
            );
            assertEq(newToken.decimals(), decimalValues[i]);
        }
    }

    function test_RevertOnInvalidDecimals() public {
        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(InvalidDecimals.selector, 19));
        depositFactory.createDeposit(
            "Deposit 19", "DEP19", 19, new uint256[](0), new SMARTComplianceModuleParamPair[](0)
        );
        vm.stopPrank();
    }

    function test_OnlySupplyManagementCanMint() public {
        _mintInitialSupply(user1);

        assertEq(deposit.balanceOf(user1), INITIAL_SUPPLY);
        assertEq(deposit.totalSupply(), INITIAL_SUPPLY);

        _updateCollateral(address(deposit), owner, INITIAL_SUPPLY + 100);

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, SMARTRoles.SUPPLY_MANAGEMENT_ROLE
            )
        );
        deposit.mint(user1, 100);
        vm.stopPrank();
    }

    function test_RoleManagement() public {
        vm.startPrank(owner);
        ISMARTTokenAccessManager(deposit.accessManager()).grantRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, user1);
        assertTrue(deposit.hasRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, user1));

        ISMARTTokenAccessManager(deposit.accessManager()).revokeRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, user1);
        assertFalse(deposit.hasRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, user1));
        vm.stopPrank();
    }

    function test_Burn() public {
        _mintInitialSupply(user1);

        vm.prank(owner);
        deposit.burn(user1, 100);

        assertEq(deposit.balanceOf(user1), INITIAL_SUPPLY - 100);
    }

    function test_onlyAdminCanPause() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, SMARTRoles.EMERGENCY_ROLE
            )
        );
        vm.prank(user1);
        deposit.pause();

        vm.prank(owner);
        deposit.pause();

        assertTrue(deposit.paused());
    }

    function test_OnlyTrustedIssuerCanUpdateCollateral() public {
        uint256 collateralAmount = 1_000_000;

        uint256 untrustedIssuerPK = 0xBAD155;
        address untrustedIssuerWallet = vm.addr(untrustedIssuerPK);
        vm.label(untrustedIssuerWallet, "Untrusted Issuer Wallet");
        ClaimUtils untrustedClaimUtils = _createClaimUtilsForIssuer(untrustedIssuerWallet, untrustedIssuerPK);
        _createIdentity(untrustedIssuerWallet);

        uint256 farFutureExpiry = block.timestamp + 3650 days; // ~10 years

        vm.startPrank(untrustedIssuerWallet);
        untrustedClaimUtils.issueCollateralClaim(address(deposit), owner, collateralAmount, farFutureExpiry);

        (uint256 amount, address claimIssuer, uint256 timestamp) = deposit.findValidCollateralClaim();
        assertEq(amount, 0); // Check initial state (untrusted issuer)
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InsufficientCollateral.selector, 100, 0));
        deposit.mint(user1, 100);
        vm.stopPrank();

        _issueCollateralClaim(address(deposit), owner, collateralAmount, farFutureExpiry);

        (amount, claimIssuer, timestamp) = deposit.findValidCollateralClaim();
        assertEq(amount, collateralAmount); // Check updated state (trusted issuer)

        vm.startPrank(owner);
        deposit.mint(user1, 100);
        vm.stopPrank();
    }

    // ERC20 custodian tests
    function test_OnlyUserManagementCanFreeze() public {
        _updateCollateral(address(deposit), address(owner), INITIAL_SUPPLY);

        vm.prank(owner);
        deposit.mint(user1, 100);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user2, SMARTRoles.CUSTODIAN_ROLE
            )
        );
        deposit.freezePartialTokens(user1, 100);

        vm.prank(owner);
        deposit.freezePartialTokens(user1, 100);

        assertEq(deposit.getFrozenTokens(user1), 100);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user1, 0, 100));
        deposit.transfer(user2, 100);

        vm.prank(owner);
        deposit.unfreezePartialTokens(user1, 100);

        assertEq(deposit.getFrozenTokens(user1), 0);
    }

    //Transfer and approval tests
    function test_TransferAndApproval() public {
        _mintInitialSupply(user1);

        vm.prank(user1);
        deposit.approve(spender, 100);
        assertEq(deposit.allowance(user1, spender), 100);

        vm.prank(spender);
        deposit.transferFrom(user1, user2, 50);
        assertEq(deposit.balanceOf(user2), 50);
        assertEq(deposit.allowance(user1, spender), 50);
    }

    function test_DepositForcedTransfer() public {
        _mintInitialSupply(user1);

        vm.prank(owner);
        deposit.forcedTransfer(user1, user2, INITIAL_SUPPLY);

        assertEq(deposit.balanceOf(user1), 0);
        assertEq(deposit.balanceOf(user2), INITIAL_SUPPLY);
    }

    function test_onlySupplyManagementCanForceTransfer() public {
        _mintInitialSupply(user1);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user2, SMARTRoles.CUSTODIAN_ROLE
            )
        );
        deposit.forcedTransfer(user1, user2, INITIAL_SUPPLY);
    }

    // Test for recoverERC20 function
    function test_RecoverERC20() public {
        // Create a mock token
        MockedERC20Token mockToken = new MockedERC20Token("Mock", "MCK", DECIMALS);

        vm.startPrank(owner);
        mockToken.mint(address(deposit), 1000);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(address(deposit)), 1000);

        // Test recovery by owner (who has DEFAULT_ADMIN_ROLE)
        vm.startPrank(owner);
        deposit.recoverERC20(address(mockToken), user1, 500);
        vm.stopPrank();

        // Verify tokens were recovered
        assertEq(mockToken.balanceOf(address(deposit)), 500);
        assertEq(mockToken.balanceOf(user1), 500);

        // Test recovery by non-admin
        vm.startPrank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user2, SMARTRoles.EMERGENCY_ROLE
            )
        );
        deposit.recoverERC20(address(mockToken), user1, 500);
        vm.stopPrank();
    }

    // Test recoverERC20 revert on invalid address
    function test_RecoverERC20RevertOnInvalidAddress() public {
        // Test recovering from address(0)
        vm.startPrank(owner);
        vm.expectRevert(); // ZeroAddressNotAllowed
        deposit.recoverERC20(address(0), user1, 100);
        vm.stopPrank();

        // Test recovering own token (should revert)
        vm.startPrank(owner);
        vm.expectRevert(); // CannotRecoverSelf
        deposit.recoverERC20(address(deposit), user1, 100);
        vm.stopPrank();
    }

    // Test recoverERC20 revert on insufficient balance
    function test_RecoverERC20RevertOnInsufficientBalance() public {
        // Create a mock token
        MockedERC20Token mockToken = new MockedERC20Token("Mock", "MCK", DECIMALS);

        vm.startPrank(owner);
        mockToken.mint(address(deposit), 100);
        vm.stopPrank();

        // Test recovering more than balance
        vm.startPrank(owner);
        vm.expectRevert(); // InsufficientTokenBalance
        deposit.recoverERC20(address(mockToken), user1, 200);
        vm.stopPrank();
    }
}
