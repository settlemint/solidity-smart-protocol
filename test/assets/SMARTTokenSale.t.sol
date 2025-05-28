// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { AbstractSMARTAssetTest } from "./AbstractSMARTAssetTest.sol";
import { MockedERC20Token } from "../utils/mocks/MockedERC20Token.sol";
import { TestConstants } from "../Constants.sol";
import { SMARTComplianceModuleParamPair } from "../../contracts/interface/structs/SMARTComplianceModuleParamPair.sol";
import { SMARTRoles } from "../../contracts/assets/SMARTRoles.sol";
import { SMARTSystemRoles } from "../../contracts/system/SMARTSystemRoles.sol";
import { ISMARTTokenSale } from "../../contracts/interface/ISMARTTokenSale.sol";
import { SMARTTokenSale } from "../../contracts/extensions/token-sale/SMARTTokenSale.sol";
import { SMARTTokenSaleProxy } from "../../contracts/extensions/token-sale/SMARTTokenSaleProxy.sol";
import { SMARTTokenSaleFactory } from "../../contracts/extensions/token-sale/SMARTTokenSaleFactory.sol";
import { ISMARTEquity } from "../../contracts/assets/equity/ISMARTEquity.sol";
import { ISMARTEquityFactory } from "../../contracts/assets/equity/ISMARTEquityFactory.sol";
import { SMARTEquityFactoryImplementation } from "../../contracts/assets/equity/SMARTEquityFactoryImplementation.sol";
import { SMARTEquityImplementation } from "../../contracts/assets/equity/SMARTEquityImplementation.sol";
import { ISMARTTokenAccessManager } from "../../contracts/extensions/access-managed/ISMARTTokenAccessManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { SMARTTopics } from "../../contracts/system/SMARTTopics.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SMARTTokenSaleTest is AbstractSMARTAssetTest {
    // Contracts
    SMARTTokenSale public tokenSaleImplementation;
    SMARTTokenSaleFactory public tokenSaleFactory;
    ISMARTTokenSale public tokenSale;
    ISMARTEquityFactory public equityFactory;
    ISMARTEquity public smartToken;
    MockedERC20Token public usdToken;
    MockedERC20Token public eurToken;

    // Test accounts
    address public owner;
    address public saleAdmin;
    address public buyer1;
    address public buyer2;
    address public buyer3; // Non-verified buyer
    address public fundsManager;

    // Sale parameters
    uint256 public saleStart;
    uint256 public saleDuration = 30 days;
    uint256 public hardCap = 1000 * 10 ** 18; // 1000 tokens
    uint256 public basePrice = 1 ether; // 1 ETH per token
    uint256 public minPurchase = 1 * 10 ** 18; // 1 token minimum
    uint256 public maxPurchase = 100 * 10 ** 18; // 100 tokens maximum

    // Constants
    uint8 public constant TOKEN_DECIMALS = 18;
    uint256 public constant INITIAL_TOKEN_SUPPLY = 10_000 * 10 ** 18;

    // Events to test
    event TokensPurchased(
        address indexed buyer, address indexed paymentCurrency, uint256 paymentAmount, uint256 tokenAmount
    );
    event TokensWithdrawn(address indexed buyer, uint256 amount);
    event SaleStatusUpdated(uint8 newStatus);
    event SaleParametersUpdated(address indexed operator);
    event FundsWithdrawn(address indexed recipient, address indexed currency, uint256 amount);
    event PaymentCurrencyAdded(address indexed currency, uint256 priceRatio);
    event PaymentCurrencyRemoved(address indexed currency);

    function setUp() public {
        // Create test accounts
        owner = makeAddr("owner");
        saleAdmin = makeAddr("saleAdmin");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        buyer3 = makeAddr("buyer3");
        fundsManager = makeAddr("fundsManager");

        // Initialize SMART system
        setUpSMART(owner);

        // Set up identities for verified buyers
        _setUpIdentity(owner, "Owner");
        _setUpIdentity(saleAdmin, "Sale Admin");
        _setUpIdentity(buyer1, "Buyer 1");
        _setUpIdentity(buyer2, "Buyer 2");
        _setUpIdentity(fundsManager, "Funds Manager");
        // buyer3 is intentionally not set up to test non-verified buyer rejection

        // Deploy mock payment tokens
        usdToken = new MockedERC20Token("Mock USD", "mUSD", 6);
        eurToken = new MockedERC20Token("Mock EUR", "mEUR", 18);

        // Mint payment tokens to buyers
        deal(buyer1, 100 ether); // ETH for buyer1
        deal(buyer2, 50 ether); // ETH for buyer2
        deal(buyer3, 10 ether); // ETH for unverified buyer

        usdToken.mint(buyer1, 100_000 * 10 ** 6); // $100,000 USD
        usdToken.mint(buyer2, 50_000 * 10 ** 6); // $50,000 USD
        eurToken.mint(buyer1, 50_000 * 10 ** 18); // €50,000 EUR

        // Set up the Equity Factory
        SMARTEquityFactoryImplementation equityFactoryImpl = new SMARTEquityFactoryImplementation(address(forwarder));
        SMARTEquityImplementation equityImpl = new SMARTEquityImplementation(address(forwarder));

        vm.startPrank(platformAdmin);
        equityFactory = ISMARTEquityFactory(
            systemUtils.system().createTokenFactory("Equity", address(equityFactoryImpl), address(equityImpl))
        );

        // Grant registrar role to owner so that he can create the equity
        IAccessControl(address(equityFactory)).grantRole(SMARTSystemRoles.TOKEN_DEPLOYER_ROLE, owner);
        vm.stopPrank();

        // Create equity token using factory
        vm.prank(owner);
        address tokenAddress = equityFactory.createEquity(
            "Test SMART Token",
            "TST",
            TOKEN_DECIMALS,
            "Class A",
            "Common",
            new uint256[](0), // requiredClaimTopics
            new SMARTComplianceModuleParamPair[](0) // initialModulePairs
        );

        smartToken = ISMARTEquity(tokenAddress);

        // Grant necessary roles to owner for token operations - after token creation
        _grantAllRoles(smartToken.accessManager(), owner, owner);

        // Mint tokens to owner for sale
        vm.prank(owner);
        smartToken.mint(owner, INITIAL_TOKEN_SUPPLY);

        // Deploy token sale contracts
        tokenSaleImplementation = new SMARTTokenSale(address(forwarder));
        SMARTTokenSaleFactory tokenSaleFactoryImpl = new SMARTTokenSaleFactory(address(forwarder));

        // Deploy factory through proxy pattern with owner as caller
        vm.prank(owner);
        ERC1967Proxy factoryProxy = new ERC1967Proxy(
            address(tokenSaleFactoryImpl),
            abi.encodeCall(tokenSaleFactoryImpl.initialize, (address(tokenSaleImplementation)))
        );
        tokenSaleFactory = SMARTTokenSaleFactory(address(factoryProxy));

        // Set sale start time to future
        saleStart = block.timestamp + 1 hours;

        // Deploy token sale through factory
        vm.prank(owner);
        address saleAddress = tokenSaleFactory.deployTokenSale(
            address(smartToken),
            saleAdmin,
            saleStart,
            saleDuration,
            hardCap,
            basePrice,
            block.timestamp // saltNonce
        );

        tokenSale = ISMARTTokenSale(saleAddress);

        // Set up identity for the token sale contract so it can receive tokens
        _setUpIdentity(address(tokenSale), "Token Sale Contract");

        // Transfer tokens to sale contract
        vm.prank(owner);
        smartToken.transfer(address(tokenSale), hardCap);

        // Note: The factory already grants SALE_ADMIN_ROLE and FUNDS_MANAGER_ROLE to saleAdmin
        // No additional role setup needed here
    }

    // --- Initialization Tests ---

    function test_Initialize() public {
        // Verify basic parameters
        assertEq(tokenSale.saleStatus(), uint8(0)); // SETUP status

        (uint256 soldAmount, uint256 remainingTokens, uint256 startTime, uint256 endTime) = tokenSale.getSaleInfo();
        assertEq(soldAmount, 0);
        assertEq(remainingTokens, hardCap);
        assertEq(startTime, saleStart);
        assertEq(endTime, saleStart + saleDuration);

        // Verify roles
        SMARTTokenSale concreteSale = SMARTTokenSale(address(tokenSale));
        assertTrue(IAccessControl(address(tokenSale)).hasRole(concreteSale.SALE_ADMIN_ROLE(), saleAdmin));
        assertTrue(IAccessControl(address(tokenSale)).hasRole(concreteSale.FUNDS_MANAGER_ROLE(), saleAdmin));
        // Note: fundsManager does not automatically get FUNDS_MANAGER_ROLE from factory
    }

    function test_RevertOnInvalidInitialize() public {
        // Create a new implementation for testing
        SMARTTokenSale newImplementation = new SMARTTokenSale(address(forwarder));

        // Try to create a proxy with invalid initialization data
        vm.expectRevert(ISMARTTokenSale.Unauthorized.selector);
        new ERC1967Proxy(
            address(newImplementation),
            abi.encodeCall(
                newImplementation.initialize,
                (
                    address(0), // Invalid token address
                    saleStart,
                    saleDuration,
                    hardCap,
                    basePrice
                )
            )
        );
    }

    // --- Configuration Tests ---

    function test_ConfigureVesting() public {
        uint256 vestingStart = saleStart + saleDuration + 1 days;
        uint256 vestingDuration = 365 days;
        uint256 vestingCliff = 90 days;

        vm.expectEmit(true, false, false, false);
        emit SaleParametersUpdated(saleAdmin);

        vm.prank(saleAdmin);
        tokenSale.configureVesting(vestingStart, vestingDuration, vestingCliff);
    }

    function test_AddPaymentCurrency() public {
        uint256 usdPriceRatio = 1000 * 10 ** 18; // 1000 USD per token (scaled by 10^18)

        vm.expectEmit(true, false, false, true);
        emit PaymentCurrencyAdded(address(usdToken), usdPriceRatio);

        vm.prank(saleAdmin);
        tokenSale.addPaymentCurrency(address(usdToken), usdPriceRatio);
    }

    function test_RemovePaymentCurrency() public {
        // First add a currency
        vm.prank(saleAdmin);
        tokenSale.addPaymentCurrency(address(usdToken), 1000 * 10 ** 18);

        vm.expectEmit(true, false, false, false);
        emit PaymentCurrencyRemoved(address(usdToken));

        vm.prank(saleAdmin);
        tokenSale.removePaymentCurrency(address(usdToken));
    }

    function test_SetPurchaseLimits() public {
        uint256 newMinPurchase = 5 * 10 ** 18;
        uint256 newMaxPurchase = 200 * 10 ** 18;

        vm.expectEmit(true, false, false, false);
        emit SaleParametersUpdated(saleAdmin);

        vm.prank(saleAdmin);
        tokenSale.setPurchaseLimits(newMinPurchase, newMaxPurchase);
    }

    function test_RevertOnInvalidPurchaseLimits() public {
        vm.expectRevert(ISMARTTokenSale.InvalidPriceCalculation.selector);
        vm.prank(saleAdmin);
        tokenSale.setPurchaseLimits(100 * 10 ** 18, 50 * 10 ** 18); // min > max
    }

    // --- Sale Lifecycle Tests ---

    function test_ActivateSale() public {
        vm.expectEmit(false, false, false, true);
        emit SaleStatusUpdated(1); // ACTIVE status

        vm.prank(saleAdmin);
        tokenSale.activateSale();

        assertEq(tokenSale.saleStatus(), 1);
    }

    function test_RevertActivateSaleInsufficientTokens() public {
        // Create new sale with insufficient tokens
        vm.prank(owner);
        address saleAddress = tokenSaleFactory.deployTokenSale(
            address(smartToken),
            saleAdmin,
            saleStart,
            saleDuration,
            hardCap,
            basePrice,
            block.timestamp + 1 // different saltNonce
        );

        ISMARTTokenSale newSale = ISMARTTokenSale(saleAddress);

        // Set up identity for the new sale contract so it can receive tokens
        _setUpIdentity(address(newSale), "New Token Sale Contract");

        // Only transfer half the required tokens
        vm.prank(owner);
        smartToken.transfer(address(newSale), hardCap / 2);

        vm.expectRevert(ISMARTTokenSale.InsufficientTokenBalance.selector);
        vm.prank(saleAdmin);
        newSale.activateSale();
    }

    function test_PauseSale() public {
        vm.prank(saleAdmin);
        tokenSale.activateSale();

        vm.expectEmit(false, false, false, true);
        emit SaleStatusUpdated(2); // PAUSED status

        vm.prank(saleAdmin);
        tokenSale.pauseSale();

        assertEq(tokenSale.saleStatus(), 2);
    }

    function test_EndSale() public {
        vm.expectEmit(false, false, false, true);
        emit SaleStatusUpdated(3); // ENDED status

        vm.prank(saleAdmin);
        tokenSale.endSale();

        assertEq(tokenSale.saleStatus(), 3);
    }

    // --- Purchase Tests ---

    function test_BuyTokensWithETH() public {
        _activateSale();
        _jumpToSaleStart();

        uint256 ethAmount = 5 ether;
        uint256 expectedTokens = ethAmount; // 1:1 ratio

        vm.expectEmit(true, true, false, true);
        emit TokensPurchased(buyer1, address(0), ethAmount, expectedTokens);

        vm.prank(buyer1);
        uint256 tokenAmount = tokenSale.buyTokens{ value: ethAmount }();

        assertEq(tokenAmount, expectedTokens);
        assertEq(tokenSale.purchasedAmount(buyer1), expectedTokens);
        assertEq(smartToken.balanceOf(buyer1), expectedTokens); // No vesting
    }

    function test_BuyTokensWithERC20() public {
        _activateSale();
        _jumpToSaleStart();

        // Configure USD payment with 1000 USD per token
        uint256 usdPriceRatio = 1000 * 10 ** 18;
        vm.prank(saleAdmin);
        tokenSale.addPaymentCurrency(address(usdToken), usdPriceRatio);

        uint256 usdAmount = 5000 * 10 ** 6; // $5000 USD
        uint256 expectedTokens = 5 * 10 ** 18; // 5 tokens

        // Approve spending
        vm.prank(buyer1);
        usdToken.approve(address(tokenSale), usdAmount);

        vm.expectEmit(true, true, false, true);
        emit TokensPurchased(buyer1, address(usdToken), usdAmount, expectedTokens);

        vm.prank(buyer1);
        uint256 tokenAmount = tokenSale.buyTokensWithERC20(address(usdToken), usdAmount);

        assertEq(tokenAmount, expectedTokens);
        assertEq(tokenSale.purchasedAmount(buyer1), expectedTokens);
        assertEq(smartToken.balanceOf(buyer1), expectedTokens);
    }

    function test_RevertBuyTokensNotEligible() public {
        _activateSale();
        _jumpToSaleStart();

        vm.expectRevert(ISMARTTokenSale.BuyerNotEligible.selector);
        vm.prank(buyer3); // Unverified buyer
        tokenSale.buyTokens{ value: 1 ether }();
    }

    function test_RevertBuyTokensSaleNotActive() public {
        // Sale is in SETUP status
        vm.expectRevert(ISMARTTokenSale.SaleNotActive.selector);
        vm.prank(buyer1);
        tokenSale.buyTokens{ value: 1 ether }();
    }

    function test_RevertBuyTokensSaleNotStarted() public {
        _activateSale();
        // Don't jump to sale start

        vm.expectRevert(ISMARTTokenSale.SaleNotStarted.selector);
        vm.prank(buyer1);
        tokenSale.buyTokens{ value: 1 ether }();
    }

    function test_RevertBuyTokensSaleEnded() public {
        _activateSale();
        _jumpToSaleEnd();

        vm.expectRevert(ISMARTTokenSale.SaleEnded.selector);
        vm.prank(buyer1);
        tokenSale.buyTokens{ value: 1 ether }();
    }

    function test_RevertBuyTokensAmountTooLow() public {
        _activateSale();
        _jumpToSaleStart();

        vm.expectRevert(ISMARTTokenSale.PurchaseAmountTooLow.selector);
        vm.prank(buyer1);
        tokenSale.buyTokens{ value: 0 }();
    }

    function test_RevertBuyTokensExceedsMaxAllocation() public {
        _activateSale();
        _jumpToSaleStart();

        vm.prank(saleAdmin);
        tokenSale.setPurchaseLimits(1 * 10 ** 18, 5 * 10 ** 18); // Max 5 tokens

        vm.expectRevert(ISMARTTokenSale.MaximumAllocationExceeded.selector);
        vm.prank(buyer1);
        tokenSale.buyTokens{ value: 10 ether }(); // Trying to buy 10 tokens
    }

    function test_RevertBuyTokensExceedsHardCap() public {
        _activateSale();
        _jumpToSaleStart();

        // First, buy most of the hard cap to get close to the limit
        vm.prank(buyer1);
        tokenSale.buyTokens{ value: 95 ether }(); // Buy 95 tokens, leaving 905 tokens available

        // Give buyer2 enough ETH to make the purchase
        deal(buyer2, 1000 ether);

        // Now try to buy more than the remaining hard cap
        // Remaining: 905 tokens, try to buy 910 tokens (which should exceed the remaining cap)
        vm.expectRevert(ISMARTTokenSale.HardCapExceeded.selector);
        vm.prank(buyer2);
        tokenSale.buyTokens{ value: 910 ether }(); // Try to buy 910 tokens when only 905 are left
    }

    function test_RevertBuyTokensUnsupportedCurrency() public {
        _activateSale();
        _jumpToSaleStart();

        vm.expectRevert(ISMARTTokenSale.UnsupportedPaymentCurrency.selector);
        vm.prank(buyer1);
        tokenSale.buyTokensWithERC20(address(usdToken), 1000 * 10 ** 6);
    }

    // --- Vesting Tests ---

    function test_BuyTokensWithVesting() public {
        _configureVesting();
        _activateSale();
        _jumpToSaleStart();

        uint256 ethAmount = 5 ether;

        vm.prank(buyer1);
        tokenSale.buyTokens{ value: ethAmount }();

        assertEq(tokenSale.purchasedAmount(buyer1), ethAmount);
        assertEq(smartToken.balanceOf(buyer1), 0); // Tokens are vested
        assertEq(tokenSale.withdrawableAmount(buyer1), 0); // Before cliff
    }

    function test_WithdrawVestedTokens() public {
        _configureVesting();
        _activateSale();
        _jumpToSaleStart();

        uint256 purchaseAmount = 10 * 10 ** 18;

        vm.prank(buyer1);
        tokenSale.buyTokens{ value: purchaseAmount }();

        // Jump past cliff but not full vesting
        vm.warp(saleStart + saleDuration + 95 days); // 5 days after cliff

        uint256 withdrawable = tokenSale.withdrawableAmount(buyer1);
        assertGt(withdrawable, 0);
        assertLt(withdrawable, purchaseAmount); // Not fully vested yet

        vm.expectEmit(true, false, false, true);
        emit TokensWithdrawn(buyer1, withdrawable);

        vm.prank(buyer1);
        uint256 withdrawn = tokenSale.withdrawTokens();

        assertEq(withdrawn, withdrawable);
        assertEq(smartToken.balanceOf(buyer1), withdrawable);
    }

    function test_WithdrawFullyVestedTokens() public {
        _configureVesting();
        _activateSale();
        _jumpToSaleStart();

        uint256 purchaseAmount = 10 * 10 ** 18;

        vm.prank(buyer1);
        tokenSale.buyTokens{ value: purchaseAmount }();

        // Jump past full vesting period
        vm.warp(saleStart + saleDuration + 400 days); // Past full vesting

        uint256 withdrawable = tokenSale.withdrawableAmount(buyer1);
        assertEq(withdrawable, purchaseAmount); // Fully vested

        vm.prank(buyer1);
        uint256 withdrawn = tokenSale.withdrawTokens();

        assertEq(withdrawn, purchaseAmount);
        assertEq(smartToken.balanceOf(buyer1), purchaseAmount);
    }

    function test_RevertWithdrawNoTokens() public {
        _activateSale();
        _jumpToSaleStart();

        vm.expectRevert(ISMARTTokenSale.PurchaseAmountTooLow.selector);
        vm.prank(buyer1);
        tokenSale.withdrawTokens();
    }

    // --- Price Calculation Tests ---

    function test_GetTokenPriceETH() public {
        uint256 tokenAmount = 5 * 10 ** 18;
        uint256 expectedPrice = 5 ether; // 1:1 ratio

        uint256 price = tokenSale.getTokenPrice(address(0), tokenAmount);
        assertEq(price, expectedPrice);
    }

    function test_GetTokenPriceERC20() public {
        uint256 usdPriceRatio = 1000 * 10 ** 18; // 1000 USD per token
        vm.prank(saleAdmin);
        tokenSale.addPaymentCurrency(address(usdToken), usdPriceRatio);

        uint256 tokenAmount = 5 * 10 ** 18; // 5 tokens
        uint256 expectedPrice = 5000 * 10 ** 6; // $5000 (accounting for USD decimals)

        uint256 price = tokenSale.getTokenPrice(address(usdToken), tokenAmount);
        assertEq(price, expectedPrice);
    }

    // --- Funds Management Tests ---

    function test_WithdrawETHFunds() public {
        _activateSale();
        _jumpToSaleStart();

        // Make some purchases
        vm.prank(buyer1);
        tokenSale.buyTokens{ value: 5 ether }();

        uint256 initialBalance = saleAdmin.balance;
        uint256 contractBalance = address(tokenSale).balance;

        vm.expectEmit(true, true, false, true);
        emit FundsWithdrawn(saleAdmin, address(0), contractBalance);

        vm.prank(saleAdmin);
        uint256 withdrawn = tokenSale.withdrawFunds(address(0), saleAdmin);

        assertEq(withdrawn, contractBalance);
        assertEq(saleAdmin.balance, initialBalance + contractBalance);
        assertEq(address(tokenSale).balance, 0);
    }

    function test_WithdrawERC20Funds() public {
        _activateSale();
        _jumpToSaleStart();

        // Configure USD payment
        vm.prank(saleAdmin);
        tokenSale.addPaymentCurrency(address(usdToken), 1000 * 10 ** 18);

        // Make purchase with USD
        uint256 usdAmount = 5000 * 10 ** 6;
        vm.prank(buyer1);
        usdToken.approve(address(tokenSale), usdAmount);
        vm.prank(buyer1);
        tokenSale.buyTokensWithERC20(address(usdToken), usdAmount);

        uint256 initialBalance = usdToken.balanceOf(saleAdmin);
        uint256 contractBalance = usdToken.balanceOf(address(tokenSale));

        vm.expectEmit(true, true, false, true);
        emit FundsWithdrawn(saleAdmin, address(usdToken), contractBalance);

        vm.prank(saleAdmin);
        uint256 withdrawn = tokenSale.withdrawFunds(address(usdToken), saleAdmin);

        assertEq(withdrawn, contractBalance);
        assertEq(usdToken.balanceOf(saleAdmin), initialBalance + contractBalance);
        assertEq(usdToken.balanceOf(address(tokenSale)), 0);
    }

    function test_RevertWithdrawFundsUnauthorized() public {
        vm.expectRevert();
        vm.prank(buyer1);
        tokenSale.withdrawFunds(address(0), buyer1);
    }

    // --- Complex Scenarios ---

    function test_MultipleBuyersScenario() public {
        _activateSale();
        _jumpToSaleStart();

        // Buyer 1 purchases with ETH
        vm.prank(buyer1);
        tokenSale.buyTokens{ value: 10 ether }();

        // Configure USD and buyer 2 purchases with USD
        vm.prank(saleAdmin);
        tokenSale.addPaymentCurrency(address(usdToken), 1000 * 10 ** 18);

        uint256 usdAmount = 5000 * 10 ** 6; // $5000 for 5 tokens
        vm.prank(buyer2);
        usdToken.approve(address(tokenSale), usdAmount);
        vm.prank(buyer2);
        tokenSale.buyTokensWithERC20(address(usdToken), usdAmount);

        // Verify purchases
        assertEq(tokenSale.purchasedAmount(buyer1), 10 * 10 ** 18);
        assertEq(tokenSale.purchasedAmount(buyer2), 5 * 10 ** 18);

        (uint256 soldAmount,,,) = tokenSale.getSaleInfo();
        assertEq(soldAmount, 15 * 10 ** 18);
    }

    function test_SaleProgression() public {
        // Start in SETUP
        assertEq(tokenSale.saleStatus(), 0);

        // Activate sale
        vm.prank(saleAdmin);
        tokenSale.activateSale();
        assertEq(tokenSale.saleStatus(), 1);

        // Pause sale
        vm.prank(saleAdmin);
        tokenSale.pauseSale();
        assertEq(tokenSale.saleStatus(), 2);

        // Resume sale (by ending and creating new one for simplicity)
        vm.prank(saleAdmin);
        tokenSale.endSale();
        assertEq(tokenSale.saleStatus(), 3);
    }

    // --- Helper Functions ---

    function _activateSale() internal {
        vm.prank(saleAdmin);
        tokenSale.activateSale();
    }

    function _jumpToSaleStart() internal {
        vm.warp(saleStart + 1);
    }

    function _jumpToSaleEnd() internal {
        vm.warp(saleStart + saleDuration + 1);
    }

    function _configureVesting() internal {
        uint256 vestingStart = saleStart + saleDuration + 1 days;
        uint256 vestingDuration = 365 days;
        uint256 vestingCliff = 90 days;

        vm.prank(saleAdmin);
        tokenSale.configureVesting(vestingStart, vestingDuration, vestingCliff);
    }
}
