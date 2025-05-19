// // SPDX-License-Identifier: FSL-1.1-MIT
// pragma solidity 0.8.28;

// import { Test } from "forge-std/Test.sol";
// import { AbstractSMARTAssetTest } from "./AbstractSMARTAssetTest.sol";

// import { ClaimUtils } from "../utils/ClaimUtils.sol";
// import { SMARTDeposit } from "../../contracts/assets/SMARTDeposit.sol";
// import { SMARTConstants } from "../../contracts/assets/SMARTConstants.sol";
// import { SMARTRoles } from "../../contracts/assets/SMARTRoles.sol";
// import { InvalidDecimals } from "../../contracts/extensions/core/SMARTErrors.sol";
// import { SMARTComplianceModuleParamPair } from
// "../../contracts/interface/structs/SMARTComplianceModuleParamPair.sol";
// import { InsufficientCollateral } from "../../contracts/extensions/collateral/SMARTCollateralErrors.sol";
// import { console } from "forge-std/console.sol";
// import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
// import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
// import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// contract SMARTDepositTest is AbstractSMARTAssetTest {
//     address public owner;
//     address public user1;
//     address public user2;
//     address public spender;

//     SMARTDeposit public deposit;

//     uint8 public constant DECIMALS = 8;
//     uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** DECIMALS;
//     uint48 public constant COLLATERAL_LIVENESS = 7 days;

//     function setUp() public {
//         // Create identities
//         owner = makeAddr("owner");
//         user1 = makeAddr("user1");
//         user2 = makeAddr("user2");
//         spender = makeAddr("spender");

//         // Initialize SMART
//         setUpSMART(owner);

//         // Initialize identities
//         address[] memory identities = new address[](4);
//         identities[0] = owner;
//         identities[1] = user1;
//         identities[2] = user2;
//         identities[3] = spender;
//         _setUpIdentities(identities);

//         deposit =
//             _createDeposit("Deposit", "DEP", DECIMALS, new uint256[](0), new SMARTComplianceModuleParamPair[](0),
// owner);
//         vm.label(address(deposit), "Deposit");
//     }

//     function _createDeposit(
//         string memory name,
//         string memory symbol,
//         uint8 decimals,
//         uint256[] memory requiredClaimTopics,
//         SMARTComplianceModuleParamPair[] memory initialModulePairs,
//         address owner_
//     )
//         internal
//         returns (SMARTDeposit result)
//     {
//         vm.startPrank(owner);
//         SMARTDeposit smartDepositImplementation = new SMARTDeposit(address(forwarder));
//         vm.label(address(smartDepositImplementation), "Deposit Implementation");
//         bytes memory data = abi.encodeWithSelector(
//             SMARTDeposit.initialize.selector,
//             name,
//             symbol,
//             decimals,
//             requiredClaimTopics,
//             initialModulePairs,
//             identityRegistry,
//             compliance,
//             address(accessManager)
//         );

//         result = SMARTDeposit(address(new ERC1967Proxy(address(smartDepositImplementation), data)));
//         vm.label(address(result), "Deposit");
//         vm.stopPrank();

//         _grantAllRoles(owner, owner);

//         _createAndSetTokenOnchainID(address(result), owner_);

//         return result;
//     }

//     function _updateCollateral(address token, address tokenIssuer, uint256 collateralAmount) internal {
//         // Use a very large amount and a long expiry
//         uint256 farFutureExpiry = block.timestamp + 3650 days; // ~10 years

//         vm.startPrank(tokenIssuer);
//         _issueCollateralClaim(address(token), tokenIssuer, collateralAmount, farFutureExpiry);
//         vm.stopPrank();
//     }

//     function _mintInitialSupply(address recipient) internal {
//         _updateCollateral(address(deposit), owner, INITIAL_SUPPLY);
//         vm.prank(owner);
//         deposit.mint(recipient, INITIAL_SUPPLY);
//     }

//     function test_InitialState() public view {
//         assertEq(deposit.name(), "Deposit");
//         assertEq(deposit.symbol(), "DEP");
//         assertEq(deposit.decimals(), DECIMALS);
//         assertEq(deposit.totalSupply(), 0);
//         assertTrue(deposit.hasRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, owner));
//         assertTrue(deposit.hasRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE, owner));
//         assertTrue(deposit.hasRole(SMARTRoles.CUSTODIAN_ROLE, owner));
//         assertTrue(deposit.hasRole(SMARTRoles.EMERGENCY_ROLE, owner));
//     }

//     function test_DifferentDecimals() public {
//         uint8[] memory decimalValues = new uint8[](4);
//         decimalValues[0] = 0; // Test zero decimals
//         decimalValues[1] = 6;
//         decimalValues[2] = 8; // Test max decimals

//         for (uint256 i = 0; i < decimalValues.length; ++i) {
//             SMARTDeposit newToken = _createDeposit(
//                 "Deposit", "DEP", decimalValues[i], new uint256[](0), new SMARTComplianceModuleParamPair[](0), owner
//             );
//             assertEq(newToken.decimals(), decimalValues[i]);
//         }
//     }

//     function test_RevertOnInvalidDecimals() public {
//         vm.startPrank(owner);
//         SMARTDeposit smartDepositImplementation = new SMARTDeposit(address(forwarder));

//         bytes memory data = abi.encodeWithSelector(
//             SMARTDeposit.initialize.selector,
//             "Deposit",
//             "DEP",
//             19,
//             new uint256[](0),
//             new SMARTComplianceModuleParamPair[](0),
//             identityRegistry,
//             compliance,
//             address(accessManager)
//         );

//         vm.expectRevert(abi.encodeWithSelector(InvalidDecimals.selector, 19));
//         new ERC1967Proxy(address(smartDepositImplementation), data);
//         vm.stopPrank();
//     }

//     function test_OnlySupplyManagementCanMint() public {
//         _mintInitialSupply(user1);

//         assertEq(deposit.balanceOf(user1), INITIAL_SUPPLY);
//         assertEq(deposit.totalSupply(), INITIAL_SUPPLY);

//         _updateCollateral(address(deposit), owner, INITIAL_SUPPLY + 100);

//         vm.startPrank(user1);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IAccessControl.AccessControlUnauthorizedAccount.selector, user1, SMARTRoles.SUPPLY_MANAGEMENT_ROLE
//             )
//         );
//         deposit.mint(user1, 100);
//         vm.stopPrank();
//     }

//     function test_RoleManagement() public {
//         vm.startPrank(owner);
//         accessManager.grantRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, user1);
//         assertTrue(deposit.hasRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, user1));

//         accessManager.revokeRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, user1);
//         assertFalse(deposit.hasRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, user1));
//         vm.stopPrank();
//     }

//     function test_Burn() public {
//         _mintInitialSupply(user1);

//         vm.prank(owner);
//         deposit.burn(user1, 100);

//         assertEq(deposit.balanceOf(user1), INITIAL_SUPPLY - 100);
//     }

//     function test_onlyAdminCanPause() public {
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IAccessControl.AccessControlUnauthorizedAccount.selector, user1, SMARTRoles.EMERGENCY_ROLE
//             )
//         );
//         vm.prank(user1);
//         deposit.pause();

//         vm.prank(owner);
//         deposit.pause();

//         assertTrue(deposit.paused());
//     }

//     function test_OnlyTrustedIssuerCanUpdateCollateral() public {
//         uint256 collateralAmount = 1_000_000;

//         uint256 untrustedIssuerPK = 0xBAD155;
//         address untrustedIssuerWallet = vm.addr(untrustedIssuerPK);
//         vm.label(untrustedIssuerWallet, "Untrusted Issuer Wallet");
//         ClaimUtils untrustedClaimUtils = _createClaimUtilsForIssuer(untrustedIssuerWallet, untrustedIssuerPK);
//         _createIdentity(untrustedIssuerWallet);

//         uint256 farFutureExpiry = block.timestamp + 3650 days; // ~10 years

//         vm.startPrank(untrustedIssuerWallet);
//         untrustedClaimUtils.issueCollateralClaim(address(deposit), owner, collateralAmount, farFutureExpiry);

//         (uint256 amount, address claimIssuer, uint256 timestamp) = deposit.findValidCollateralClaim();
//         assertEq(amount, 0); // Check initial state (untrusted issuer)
//         vm.stopPrank();

//         vm.startPrank(owner);
//         vm.expectRevert(abi.encodeWithSelector(InsufficientCollateral.selector, 100, 0));
//         deposit.mint(user1, 100);
//         vm.stopPrank();

//         _issueCollateralClaim(address(deposit), owner, collateralAmount, farFutureExpiry);

//         (amount, claimIssuer, timestamp) = deposit.findValidCollateralClaim();
//         assertEq(amount, collateralAmount); // Check updated state (trusted issuer)

//         vm.startPrank(owner);
//         deposit.mint(user1, 100);
//         vm.stopPrank();
//     }

//     // ERC20 custodian tests
//     function test_OnlyUserManagementCanFreeze() public {
//         _updateCollateral(address(deposit), address(owner), INITIAL_SUPPLY);

//         vm.prank(owner);
//         deposit.mint(user1, 100);

//         vm.prank(user2);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IAccessControl.AccessControlUnauthorizedAccount.selector, user2, SMARTRoles.CUSTODIAN_ROLE
//             )
//         );
//         deposit.freezePartialTokens(user1, 100);

//         vm.prank(owner);
//         deposit.freezePartialTokens(user1, 100);

//         assertEq(deposit.getFrozenTokens(user1), 100);

//         vm.prank(user1);
//         vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user1, 0, 100));
//         deposit.transfer(user2, 100);

//         vm.prank(owner);
//         deposit.unfreezePartialTokens(user1, 100);

//         assertEq(deposit.getFrozenTokens(user1), 0);
//     }

//     //Transfer and approval tests
//     function test_TransferAndApproval() public {
//         _mintInitialSupply(user1);

//         vm.prank(user1);
//         deposit.approve(spender, 100);
//         assertEq(deposit.allowance(user1, spender), 100);

//         vm.prank(spender);
//         deposit.transferFrom(user1, user2, 50);
//         assertEq(deposit.balanceOf(user2), 50);
//         assertEq(deposit.allowance(user1, spender), 50);
//     }

//     function test_DepositForcedTransfer() public {
//         _mintInitialSupply(user1);

//         vm.prank(owner);
//         deposit.forcedTransfer(user1, user2, INITIAL_SUPPLY);

//         assertEq(deposit.balanceOf(user1), 0);
//         assertEq(deposit.balanceOf(user2), INITIAL_SUPPLY);
//     }

//     function test_onlySupplyManagementCanForceTransfer() public {
//         _mintInitialSupply(user1);

//         vm.prank(user2);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IAccessControl.AccessControlUnauthorizedAccount.selector, user2, SMARTRoles.CUSTODIAN_ROLE
//             )
//         );
//         deposit.forcedTransfer(user1, user2, INITIAL_SUPPLY);
//     }

//     // Test for recoverERC20 function
//     function test_RecoverERC20() public {
//         // Create a mock token
//         SMARTDeposit mockToken =
//             _createDeposit("Mock", "MCK", DECIMALS, new uint256[](0), new SMARTComplianceModuleParamPair[](0),
// owner);

//         // Set up identity for the deposit contract (required to receive tokens)
//         _setUpIdentity(address(deposit));

//         // Update collateral and mint some tokens to the deposit contract
//         _updateCollateral(address(mockToken), owner, 1000);
//         vm.startPrank(owner);
//         mockToken.mint(address(deposit), 1000);
//         vm.stopPrank();

//         assertEq(mockToken.balanceOf(address(deposit)), 1000);

//         // Remove redundant identity setup for user1 (already done in setUp)

//         // Test recovery by owner (who has DEFAULT_ADMIN_ROLE)
//         vm.startPrank(owner);
//         deposit.recoverERC20(address(mockToken), user1, 500);
//         vm.stopPrank();

//         // Verify tokens were recovered
//         assertEq(mockToken.balanceOf(address(deposit)), 500);
//         assertEq(mockToken.balanceOf(user1), 500);

//         // Test recovery by non-admin
//         vm.startPrank(user2);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IAccessControl.AccessControlUnauthorizedAccount.selector, user2, SMARTRoles.EMERGENCY_ROLE
//             )
//         );
//         deposit.recoverERC20(address(mockToken), user1, 500);
//         vm.stopPrank();
//     }

//     // Test recoverERC20 revert on invalid address
//     function test_RecoverERC20RevertOnInvalidAddress() public {
//         // Test recovering from address(0)
//         vm.startPrank(owner);
//         vm.expectRevert(); // ZeroAddressNotAllowed
//         deposit.recoverERC20(address(0), user1, 100);
//         vm.stopPrank();

//         // Test recovering own token (should revert)
//         vm.startPrank(owner);
//         vm.expectRevert(); // CannotRecoverSelf
//         deposit.recoverERC20(address(deposit), user1, 100);
//         vm.stopPrank();
//     }

//     // Test recoverERC20 revert on insufficient balance
//     function test_RecoverERC20RevertOnInsufficientBalance() public {
//         // Create a mock token
//         SMARTDeposit mockToken =
//             _createDeposit("Mock", "MCK", DECIMALS, new uint256[](0), new SMARTComplianceModuleParamPair[](0),
// owner);

//         // Set up identity for the deposit contract (required to receive tokens)
//         _setUpIdentity(address(deposit));

//         // Update collateral and mint some tokens to the deposit contract
//         _updateCollateral(address(mockToken), owner, 100);
//         vm.startPrank(owner);
//         mockToken.mint(address(deposit), 100);
//         vm.stopPrank();

//         // Test recovering more than balance
//         vm.startPrank(owner);
//         vm.expectRevert(); // InsufficientTokenBalance
//         deposit.recoverERC20(address(mockToken), user1, 200);
//         vm.stopPrank();
//     }
// }
