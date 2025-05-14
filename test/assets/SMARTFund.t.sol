// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { AbstractSMARTAssetTest } from "./AbstractSMARTAssetTest.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SMARTFund } from "../../contracts/assets/SMARTFund.sol";
import { SMARTComplianceModuleParamPair } from "../../contracts/interface/structs/SMARTComplianceModuleParamPair.sol";
import { SMARTConstants } from "../../contracts/assets/SMARTConstants.sol";
import { SMARTRoles } from "../../contracts/assets/SMARTRoles.sol";
import { TokenRecovered } from "../../contracts/extensions/core/SMARTEvents.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { TokenPaused } from "../../contracts/extensions/pausable/SMARTPausableErrors.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SMARTFundTest is AbstractSMARTAssetTest {
    SMARTFund public fund;
    address public owner;
    address public investor1;
    address public investor2;

    // Constants for fund setup
    string constant NAME = "Test Fund";
    string constant SYMBOL = "TFUND";
    uint8 constant DECIMALS = 18;
    uint16 constant MANAGEMENT_FEE_BPS = 200; // 2%
    string constant FUND_CLASS = "Hedge Fund";
    string constant FUND_CATEGORY = "Long/Short Equity";

    // Test constants
    uint256 constant INITIAL_SUPPLY = 1000 ether;
    uint256 constant INVESTMENT_AMOUNT = 100 ether;

    event ManagementFeeCollected(uint256 amount, uint256 timestamp);
    event PerformanceFeeCollected(uint256 amount, uint256 timestamp);
    event TokenWithdrawn(address indexed token, address indexed to, uint256 amount, address indexed sender);

    function setUp() public override {
        super.setUp();

        // Create identities
        owner = makeAddr("owner");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");

        // Initialize identities
        address[] memory identities = new address[](3);
        identities[0] = owner;
        identities[1] = investor1;
        identities[2] = investor2;
        _setUpIdentities(identities);

        fund = _createFundAndMint(
            NAME,
            SYMBOL,
            DECIMALS,
            MANAGEMENT_FEE_BPS,
            FUND_CLASS,
            FUND_CATEGORY,
            new uint256[](0),
            new SMARTComplianceModuleParamPair[](0)
        );
        vm.label(address(fund), "Fund");
    }

    function _createFundAndMint(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint16 managementFeeBps_,
        string memory fundClass_,
        string memory fundCategory_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        internal
        returns (SMARTFund result)
    {
        vm.startPrank(owner);
        SMARTFund smartFundImplementation = new SMARTFund(address(forwarder));
        vm.label(address(smartFundImplementation), "Fund Implementation");
        bytes memory data = abi.encodeWithSelector(
            SMARTFund.initialize.selector,
            name_,
            symbol_,
            decimals_,
            managementFeeBps_,
            fundClass_,
            fundCategory_,
            requiredClaimTopics_,
            initialModulePairs_,
            identityRegistry,
            compliance
        );

        result = SMARTFund(address(new ERC1967Proxy(address(smartFundImplementation), data)));
        vm.label(address(result), "Fund");
        vm.stopPrank();

        _grantAllRoles(address(result), owner, owner);

        _createAndSetTokenOnchainID(address(result), owner);

        vm.prank(owner);
        result.mint(owner, INITIAL_SUPPLY);

        return result;
    }

    function test_InitialState() public view {
        assertEq(fund.name(), NAME);
        assertEq(fund.symbol(), SYMBOL);
        assertEq(fund.decimals(), DECIMALS);
        assertEq(fund.fundClass(), FUND_CLASS);
        assertEq(fund.fundCategory(), FUND_CATEGORY);
        assertTrue(fund.hasRole(fund.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(fund.hasRole(SMARTRoles.MINTER_ROLE, owner));
        assertTrue(fund.hasRole(SMARTRoles.TOKEN_ADMIN_ROLE, owner));
    }

    function test_Mint() public {
        vm.startPrank(owner);
        fund.mint(investor1, INVESTMENT_AMOUNT);
        vm.stopPrank();

        assertEq(fund.balanceOf(investor1), INVESTMENT_AMOUNT);
    }

    function test_CollectManagementFee() public {
        // Wait for one year
        vm.warp(block.timestamp + 365 days);

        uint256 initialOwnerBalance = fund.balanceOf(owner);

        vm.startPrank(owner);
        uint256 fee = fund.collectManagementFee();
        vm.stopPrank();

        // Expected fee = AUM * fee_rate * time_elapsed / (100% * 1 year)
        uint256 expectedFee = (INITIAL_SUPPLY * MANAGEMENT_FEE_BPS * 365 days) / (10_000 * 365 days);
        assertEq(fee, expectedFee);
        assertEq(fund.balanceOf(owner) - initialOwnerBalance, expectedFee);
    }

    function test_RecoverERC20() public {
        address mockToken = makeAddr("mockToken");
        uint256 withdrawAmount = 100 ether;

        // Setup mock token
        vm.mockCall(
            mockToken, abi.encodeWithSelector(IERC20.balanceOf.selector, address(fund)), abi.encode(withdrawAmount)
        );
        vm.mockCall(
            mockToken, abi.encodeWithSelector(IERC20.transfer.selector, investor1, withdrawAmount), abi.encode(true)
        );

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit TokenRecovered(owner, mockToken, investor1, withdrawAmount);
        fund.recoverERC20(mockToken, investor1, withdrawAmount);
        vm.stopPrank();
    }

    function test_PauseUnpause() public {
        vm.startPrank(owner);

        // Mint some tokens first
        fund.mint(owner, INVESTMENT_AMOUNT);

        // Pause the contract
        fund.pause();
        assertTrue(fund.paused());

        // Try to transfer while paused - should revert with EnforcedPause error
        vm.expectRevert(abi.encodeWithSelector(TokenPaused.selector));
        fund.transfer(investor1, INVESTMENT_AMOUNT);

        // Unpause
        fund.unpause();
        assertFalse(fund.paused());

        // Transfer should now succeed
        fund.transfer(investor1, INVESTMENT_AMOUNT);
        assertEq(fund.balanceOf(investor1), INVESTMENT_AMOUNT);

        vm.stopPrank();
    }

    function test_FundForceTransfer() public {
        vm.startPrank(owner);
        fund.mint(investor1, INVESTMENT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(owner);
        fund.forcedTransfer(investor1, investor2, INVESTMENT_AMOUNT);
        vm.stopPrank();

        assertEq(fund.balanceOf(investor1), 0);
        assertEq(fund.balanceOf(investor2), INVESTMENT_AMOUNT);
    }

    function test_onlySupplyManagementCanForceTransfer() public {
        vm.startPrank(owner);
        fund.mint(investor1, INVESTMENT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(investor2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, investor2, SMARTRoles.FORCED_TRANSFER_ROLE
            )
        );
        fund.forcedTransfer(investor1, investor2, INVESTMENT_AMOUNT);
        vm.stopPrank();
    }
}
