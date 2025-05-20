// // SPDX-License-Identifier: FSL-1.1-MIT
// pragma solidity 0.8.28;

// import { Test } from "forge-std/Test.sol";
// import { AbstractSMARTAssetTest } from "./AbstractSMARTAssetTest.sol";
// import { SMARTEquity } from "../../contracts/assets/SMARTEquity.sol";
// import { SMARTConstants } from "../../contracts/SMARTConstants.sol";
// import { SMARTRoles } from "../../contracts/SMARTRoles.sol";
// import { InvalidDecimals } from "../../contracts/extensions/core/SMARTErrors.sol";
// import { ClaimUtils } from "../../test/utils/ClaimUtils.sol";
// import { SMARTComplianceModuleParamPair } from
// "../../contracts/interface/structs/SMARTComplianceModuleParamPair.sol";
// import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
// import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
// import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// contract SMARTEquityTest is AbstractSMARTAssetTest {
//     SMARTEquity internal smartEquity;

//     address internal owner;
//     address internal user1;
//     address internal user2;
//     address internal spender;

//     uint8 public constant DECIMALS = 8;
//     string public constant NAME = "SMART Equity";
//     string public constant SYMBOL = "SMART";
//     string public constant EQUITY_CLASS = "Common";
//     string public constant EQUITY_CATEGORY = "Class A";
//     uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 8; // 1M tokens with 8 decimals

//     event Transfer(address indexed from, address indexed to, uint256 value);
//     event Approval(address indexed owner, address indexed spender, uint256 value);
//     event Paused(address account);
//     event Unpaused(address account);
//     event CustodianOperation(address indexed custodian, address indexed from, address indexed to, uint256 amount);

//     function setUp() public {
//         // Create identities
//         owner = makeAddr("owner");
//         user1 = makeAddr("user1");
//         user2 = makeAddr("user2");
//         spender = makeAddr("spender");

//         // Initialize SMART
//         setUpSMART(owner);

//         address[] memory identities = new address[](4);
//         identities[0] = owner;
//         identities[1] = user1;
//         identities[2] = user2;
//         identities[3] = spender;
//         _setUpIdentities(identities);

//         smartEquity =
//             _createEquityAndMint(NAME, SYMBOL, DECIMALS, new uint256[](0), new SMARTComplianceModuleParamPair[](0));
//         vm.label(address(smartEquity), "SMARTEquity");

//         // Fund test accounts
//         vm.deal(user1, 100 ether);
//         vm.deal(user2, 100 ether);
//         vm.deal(spender, 100 ether);
//     }

//     function _createEquityAndMint(
//         string memory name_,
//         string memory symbol_,
//         uint8 decimals_,
//         uint256[] memory requiredClaimTopics_,
//         SMARTComplianceModuleParamPair[] memory initialModulePairs_
//     )
//         internal
//         returns (SMARTEquity result)
//     {
//         vm.startPrank(owner);
//         SMARTEquity smartEquityImplementation = new SMARTEquity(address(forwarder));
//         vm.label(address(smartEquityImplementation), "Equity Implementation");

//         bytes memory data = abi.encodeWithSelector(
//             SMARTEquity.initialize.selector,
//             name_,
//             symbol_,
//             decimals_,
//             EQUITY_CLASS,
//             EQUITY_CATEGORY,
//             requiredClaimTopics_,
//             initialModulePairs_,
//             identityRegistry,
//             compliance,
//             address(accessManager)
//         );

//         result = SMARTEquity(address(new ERC1967Proxy(address(smartEquityImplementation), data)));
//         vm.label(address(result), "Equity");
//         vm.stopPrank();

//         _grantAllRoles(owner, owner);

//         _createAndSetTokenOnchainID(address(result), owner);

//         vm.prank(owner);
//         result.mint(owner, INITIAL_SUPPLY);

//         return result;
//     }

//     // Basic Token Functionality Tests
//     function test_InitialState() public view {
//         assertEq(smartEquity.name(), NAME);
//         assertEq(smartEquity.symbol(), SYMBOL);
//         assertEq(smartEquity.decimals(), DECIMALS);
//         assertTrue(smartEquity.hasRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, owner));
//         assertTrue(smartEquity.hasRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE, owner));
//         assertTrue(smartEquity.hasRole(SMARTRoles.CUSTODIAN_ROLE, owner));
//         assertTrue(smartEquity.hasRole(SMARTRoles.EMERGENCY_ROLE, owner));
//         assertEq(smartEquity.totalSupply(), INITIAL_SUPPLY);
//         assertEq(smartEquity.balanceOf(owner), INITIAL_SUPPLY);
//     }

//     function test_DifferentDecimals() public {
//         uint8[] memory decimalValues = new uint8[](4);
//         decimalValues[0] = 0; // Test zero decimals
//         decimalValues[1] = 6;
//         decimalValues[2] = 8;
//         decimalValues[3] = 18; // Test max decimals

//         for (uint256 i = 0; i < decimalValues.length; ++i) {
//             vm.startPrank(owner);
//             SMARTEquity smartEquityImplementation = new SMARTEquity(address(forwarder));

//             bytes memory data = abi.encodeWithSelector(
//                 SMARTEquity.initialize.selector,
//                 "Test SMART Equity",
//                 "TEST",
//                 decimalValues[i],
//                 EQUITY_CLASS,
//                 EQUITY_CATEGORY,
//                 new uint256[](0),
//                 new SMARTComplianceModuleParamPair[](0),
//                 identityRegistry,
//                 compliance,
//                 address(accessManager)
//             );

//             SMARTEquity newEquity = SMARTEquity(address(new ERC1967Proxy(address(smartEquityImplementation), data)));
//             vm.stopPrank();

//             assertEq(newEquity.decimals(), decimalValues[i]);
//         }
//     }

//     function test_OnlySupplyManagementCanMint() public {
//         uint256 amount = 1000 * 10 ** DECIMALS;

//         // Have owner (who has SUPPLY_MANAGEMENT_ROLE) do the minting
//         vm.startPrank(owner);
//         smartEquity.mint(user1, amount);
//         vm.stopPrank();

//         assertEq(smartEquity.balanceOf(user1), amount);
//         assertEq(smartEquity.totalSupply(), INITIAL_SUPPLY + amount);

//         // Test that non-authorized user can't mint
//         vm.startPrank(user1);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IAccessControl.AccessControlUnauthorizedAccount.selector, user1, SMARTRoles.SUPPLY_MANAGEMENT_ROLE
//             )
//         );
//         smartEquity.mint(user1, amount);
//         vm.stopPrank();
//     }

//     function test_RoleManagement() public {
//         vm.startPrank(owner);
//         accessManager.grantRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, user1);
//         assertTrue(smartEquity.hasRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, user1));

//         accessManager.revokeRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, user1);
//         assertFalse(smartEquity.hasRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, user1));
//         vm.stopPrank();
//     }

//     // ERC20 Standard Tests
//     function test_Transfer() public {
//         uint256 amount = 1000 * 10 ** DECIMALS;

//         // Have owner do the minting since they have SUPPLY_MANAGEMENT_ROLE
//         vm.startPrank(owner);
//         smartEquity.mint(user1, amount);
//         vm.stopPrank();

//         vm.startPrank(user1);
//         smartEquity.transfer(user2, 500 * 10 ** DECIMALS);
//         vm.stopPrank();

//         assertEq(smartEquity.balanceOf(user1), 500 * 10 ** DECIMALS);
//         assertEq(smartEquity.balanceOf(user2), 500 * 10 ** DECIMALS);
//     }

//     function test_Approve() public {
//         vm.startPrank(user1);
//         smartEquity.approve(spender, 1000 * 10 ** DECIMALS);
//         vm.stopPrank();
//         assertEq(smartEquity.allowance(user1, spender), 1000 * 10 ** DECIMALS);
//     }

//     function test_TransferFrom() public {
//         uint256 amount = 1000 * 10 ** DECIMALS;
//         vm.startPrank(owner);
//         smartEquity.mint(user1, amount);
//         vm.stopPrank();

//         vm.startPrank(user1);
//         smartEquity.approve(spender, amount);
//         vm.stopPrank();

//         vm.startPrank(spender);
//         smartEquity.transferFrom(user1, user2, 500 * 10 ** DECIMALS);
//         vm.stopPrank();

//         assertEq(smartEquity.balanceOf(user1), 500 * 10 ** DECIMALS);
//         assertEq(smartEquity.balanceOf(user2), 500 * 10 ** DECIMALS);
//     }

//     // Burnable Tests
//     function test_Burn() public {
//         uint256 amount = 1000 * 10 ** DECIMALS;
//         vm.startPrank(owner);
//         smartEquity.mint(user1, amount);
//         // Only owner/admin can burn
//         smartEquity.burn(user1, 500 * 10 ** DECIMALS);
//         vm.stopPrank();

//         assertEq(smartEquity.balanceOf(user1), 500 * 10 ** DECIMALS);
//         assertEq(smartEquity.totalSupply(), INITIAL_SUPPLY + 500 * 10 ** DECIMALS);
//     }

//     // Pausable Tests
//     function test_OnlyAdminCanPause() public {
//         bytes32 role = SMARTRoles.EMERGENCY_ROLE;

//         vm.startPrank(user1);
//         vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", user1, role));
//         smartEquity.pause();
//         vm.stopPrank();

//         vm.startPrank(owner);
//         smartEquity.pause();
//         vm.stopPrank();
//         assertTrue(smartEquity.paused());
//     }

//     function test_RevertWhen_TransferWhenPaused() public {
//         uint256 amount = 1000 * 10 ** DECIMALS;
//         vm.startPrank(owner);
//         smartEquity.mint(user1, amount);
//         smartEquity.pause();
//         vm.stopPrank();

//         vm.startPrank(user1);
//         vm.expectRevert(abi.encodeWithSignature("TokenPaused()"));
//         smartEquity.transfer(user2, 500 * 10 ** DECIMALS);
//         vm.stopPrank();
//     }

//     function test_PauseUnpause() public {
//         uint256 amount = 1000 * 10 ** DECIMALS;
//         vm.startPrank(owner);

//         // Mint some tokens first
//         smartEquity.mint(owner, amount);

//         // Pause the contract
//         smartEquity.pause();
//         assertTrue(smartEquity.paused());

//         // Try to transfer while paused - should revert with TokenPaused error
//         vm.expectRevert(abi.encodeWithSignature("TokenPaused()"));
//         smartEquity.transfer(user1, amount);

//         // Unpause
//         smartEquity.unpause();
//         assertFalse(smartEquity.paused());

//         // Transfer should now succeed
//         smartEquity.transfer(user1, amount);
//         assertEq(smartEquity.balanceOf(user1), amount);

//         vm.stopPrank();
//     }

//     // Custodian Tests
//     function test_OnlyUserManagementCanFreeze() public {
//         vm.startPrank(owner);
//         smartEquity.mint(user1, 100 * 10 ** DECIMALS);
//         vm.stopPrank();

//         // Test that non-authorized user can't freeze
//         vm.startPrank(user2);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IAccessControl.AccessControlUnauthorizedAccount.selector, user2, SMARTRoles.CUSTODIAN_ROLE
//             )
//         );
//         smartEquity.freezePartialTokens(user1, 50 * 10 ** DECIMALS);
//         vm.stopPrank();

//         // Test successful freezing by owner
//         vm.startPrank(owner);
//         smartEquity.freezePartialTokens(user1, 50 * 10 ** DECIMALS);
//         vm.stopPrank();

//         // Test that frozen amount can't be transferred
//         vm.startPrank(user1);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IERC20Errors.ERC20InsufficientBalance.selector, user1, 50 * 10 ** DECIMALS, 100 * 10 ** DECIMALS
//             )
//         );
//         smartEquity.transfer(user2, 100 * 10 ** DECIMALS);

//         // But can transfer less than the unfrozen amount
//         smartEquity.transfer(user2, 10 * 10 ** DECIMALS);
//         vm.stopPrank();

//         assertEq(smartEquity.balanceOf(user2), 10 * 10 ** DECIMALS);

//         // Test unfreezing and subsequent transfer
//         vm.startPrank(owner);
//         smartEquity.freezePartialTokens(user1, 0);
//         vm.stopPrank();

//         vm.startPrank(user1);
//         smartEquity.transfer(user2, 40 * 10 ** DECIMALS);
//         vm.stopPrank();

//         assertEq(smartEquity.balanceOf(user2), 50 * 10 ** DECIMALS);
//     }

//     // Voting Tests
//     function test_DelegateVoting() public {
//         uint256 amount = 1000 * 10 ** DECIMALS;
//         vm.startPrank(owner);
//         smartEquity.mint(user1, amount);
//         vm.stopPrank();

//         vm.startPrank(user1);
//         smartEquity.delegate(user2);
//         vm.stopPrank();

//         assertEq(smartEquity.delegates(user1), user2);
//         assertEq(smartEquity.getVotes(user2), amount);
//     }

//     function test_VotingPowerTransfer() public {
//         uint256 amount = 1000 * 10 ** DECIMALS;
//         vm.startPrank(owner);
//         smartEquity.mint(user1, amount);
//         vm.stopPrank();

//         vm.startPrank(user1);
//         smartEquity.delegate(user1);
//         vm.stopPrank();
//         assertEq(smartEquity.getVotes(user1), amount);

//         vm.startPrank(user1);
//         smartEquity.transfer(user2, 500 * 10 ** DECIMALS);
//         vm.stopPrank();
//         assertEq(smartEquity.getVotes(user1), 500 * 10 ** DECIMALS);
//     }

//     // Events Tests
//     function test_TransferEvent() public {
//         uint256 amount = 1000 * 10 ** DECIMALS;
//         vm.startPrank(owner);
//         smartEquity.mint(user1, amount);
//         vm.stopPrank();

//         vm.expectEmit(true, true, false, true);
//         emit Transfer(user1, user2, 500 * 10 ** DECIMALS);

//         vm.startPrank(user1);
//         smartEquity.transfer(user2, 500 * 10 ** DECIMALS);
//         vm.stopPrank();
//     }

//     function test_ApprovalEvent() public {
//         vm.expectEmit(true, true, false, true);
//         emit Approval(user1, spender, 1000 * 10 ** DECIMALS);

//         vm.startPrank(user1);
//         smartEquity.approve(spender, 1000 * 10 ** DECIMALS);
//         vm.stopPrank();
//     }

//     // Forced Transfer Tests (equivalent to clawback in Equity.t.sol)
//     function test_ForcedTransfer() public {
//         vm.startPrank(owner);
//         smartEquity.mint(user1, 1000 * 10 ** DECIMALS);
//         vm.stopPrank();

//         vm.startPrank(owner);
//         smartEquity.forcedTransfer(user1, user2, 1000 * 10 ** DECIMALS);
//         vm.stopPrank();

//         assertEq(smartEquity.balanceOf(user1), 0);
//         assertEq(smartEquity.balanceOf(user2), 1000 * 10 ** DECIMALS);
//     }

//     function test_onlySupplyManagementCanForcedTransfer() public {
//         vm.startPrank(owner);
//         smartEquity.mint(user1, 1000 * 10 ** DECIMALS);
//         vm.stopPrank();

//         vm.startPrank(user2);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IAccessControl.AccessControlUnauthorizedAccount.selector, user2, SMARTRoles.CUSTODIAN_ROLE
//             )
//         );
//         smartEquity.forcedTransfer(user1, user2, 1000 * 10 ** DECIMALS);
//         vm.stopPrank();
//     }
// }
