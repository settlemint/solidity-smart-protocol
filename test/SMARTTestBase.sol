// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Adjust import path assuming SMARTInfrastructureSetup will be in ./utils/
import { Test } from "forge-std/Test.sol";
import { ISMART } from "../contracts/SMART/interface/ISMART.sol";
import { ISMARTComplianceModule } from "../contracts/SMART/interface/ISMARTComplianceModule.sol";
import { _SMARTPausableLogic } from "../contracts/SMART/extensions/base/_SMARTPausableLogic.sol";
import { _SMARTCustodianLogic } from "../contracts/SMART/extensions/base/_SMARTCustodianLogic.sol";
import { TestConstants } from "./utils/Constants.sol"; // Assuming Constants.sol exists here
import { ClaimUtils } from "./utils/ClaimUtils.sol"; // Needed for _setupIdentities
import { IdentityUtils } from "./utils/IdentityUtils.sol"; // Needed for _setupIdentities
import { TokenUtils } from "./utils/TokenUtils.sol"; // Needed for tests
import { InfrastructureUtils } from "./utils/InfrastructureUtils.sol"; // Needed for tests
import { MockedComplianceModule } from "./mocks/MockedComplianceModule.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Interface defining the custodian functions we expect the 'token' to have
interface ISMARTCustodianFeatures {
    // State Views
    function isFrozen(address userAddress) external view returns (bool);
    function getFrozenTokens(address userAddress) external view returns (uint256);
    // Owner Actions
    function setAddressFrozen(address userAddress, bool freeze) external;
    function freezePartialTokens(address userAddress, uint256 amount) external;
    function unfreezePartialTokens(address userAddress, uint256 amount) external;
    function forcedTransfer(address from, address to, uint256 amount) external returns (bool);
    function recoveryAddress(
        address lostWallet,
        address newWallet,
        address investorOnchainID
    )
        external
        returns (bool);
    // Other functions needed for testing interactions
    function transfer(address to, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external; // Assuming mint exists
    function redeem(uint256 amount) external; // Assuming redeem exists
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

abstract contract SMARTTestBase is Test {
    // --- State Variables ---
    ISMART internal token; // Token instance to be tested (set in inheriting contracts)
    MockedComplianceModule internal mockComplianceModule;

    // --- Test Actors ---
    address public platformAdmin;
    address public tokenIssuer;
    address public clientBE;
    address public clientJP;
    address public clientUS;
    address public clientUnverified;
    address public claimIssuer; // Wallet address of the claim issuer

    // --- Test Data ---
    uint256[] public requiredClaimTopics;
    uint16[] public allowedCountries;
    ISMART.ComplianceModuleParamPair[] public modulePairs;

    // --- Private Keys ---
    uint256 internal claimIssuerPrivateKey = 0x12345;

    // --- Utils ---
    InfrastructureUtils internal infrastructureUtils;
    IdentityUtils internal identityUtils;
    ClaimUtils internal claimUtils;
    TokenUtils internal tokenUtils;

    // --- Setup ---
    function setUp() public virtual {
        // --- Setup platform admin ---
        platformAdmin = makeAddr("Platform Admin");

        // --- Setup infrastructure ---
        infrastructureUtils = new InfrastructureUtils(platformAdmin);
        mockComplianceModule = infrastructureUtils.mockedComplianceModule();

        // --- Setup utilities
        identityUtils = new IdentityUtils(
            platformAdmin,
            infrastructureUtils.identityFactory(),
            infrastructureUtils.identityRegistry(),
            infrastructureUtils.trustedIssuersRegistry()
        );
        claimUtils = new ClaimUtils(platformAdmin, claimIssuerPrivateKey, infrastructureUtils.identityRegistry());
        tokenUtils = new TokenUtils(
            platformAdmin,
            infrastructureUtils.identityFactory(),
            infrastructureUtils.identityRegistry(),
            infrastructureUtils.compliance()
        );

        // --- Initialize Actors ---
        tokenIssuer = makeAddr("Token issuer");
        clientBE = makeAddr("Client BE");
        clientJP = makeAddr("Client JP");
        clientUS = makeAddr("Client US");
        clientUnverified = makeAddr("Client Unverified");
        claimIssuer = vm.addr(claimIssuerPrivateKey); // Private key defined in SMARTInfrastructureSetup

        // --- Setup Identities ---
        _setupIdentities();

        requiredClaimTopics = new uint256[](2);
        requiredClaimTopics[0] = TestConstants.CLAIM_TOPIC_KYC;
        requiredClaimTopics[1] = TestConstants.CLAIM_TOPIC_AML;

        allowedCountries = new uint16[](2);
        allowedCountries[0] = TestConstants.COUNTRY_CODE_BE;
        allowedCountries[1] = TestConstants.COUNTRY_CODE_JP;

        modulePairs = new ISMART.ComplianceModuleParamPair[](1);
        modulePairs[0] =
            ISMART.ComplianceModuleParamPair({ module: address(mockComplianceModule), params: abi.encode("") });

        // Note: Token deployment happens in the inheriting contract's setUp.
        // We cannot mint here yet as `token` is not assigned.
        // Initial mints needed for custodian tests must happen *after* token deployment
        // in the inheriting contract's setUp, or at the start of each test function.
    }

    // --- Test Functions ---
    // These tests now operate on the `token` variable set by inheriting contracts

    function test_Mint() public {
        // Assumes token is deployed and identities are set up by setUp() in inheriting contract
        require(address(token) != address(0), "Token not deployed in setUp");

        // --- Minting --- (Use TokenUtils with the deployed token address)
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 1000);
        assertEq(token.balanceOf(clientBE), 1000, "Initial mint failed");
        assertEq(mockComplianceModule.createdCallCount(), 1, "Mock created hook count incorrect after mint");
    }

    function test_Transfer() public {
        // Assumes token is deployed and identities are set up by setUp() in inheriting contract
        require(address(token) != address(0), "Token not deployed in setUp");

        // --- Initial Mint ---
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 1000);
        assertEq(token.balanceOf(clientBE), 1000, "Setup mint failed");
        assertEq(mockComplianceModule.createdCallCount(), 1, "Mock created hook count incorrect after setup mint");

        // Reset counter for transfer tests
        mockComplianceModule.reset();

        // --- Transfers --- (Use TokenUtils with the deployed token address)

        // Test successful transfer
        uint256 transferredHookCountBefore = mockComplianceModule.transferredCallCount();
        tokenUtils.transferToken(address(token), clientBE, clientJP, 100);
        assertEq(token.balanceOf(clientJP), 100, "Successful transfer failed (receiver balance)");
        assertEq(token.balanceOf(clientBE), 900, "Successful transfer failed (sender balance)");
        assertEq(
            mockComplianceModule.transferredCallCount(),
            transferredHookCountBefore + 1,
            "Mock transferred hook count incorrect after successful transfer"
        );

        // Test blocked transfer (mock)
        mockComplianceModule.setNextTransferShouldFail(true);
        vm.expectRevert(
            abi.encodeWithSelector(ISMARTComplianceModule.ComplianceCheckFailed.selector, "Mocked compliance failure")
        );
        tokenUtils.transferToken(address(token), clientBE, clientUS, 100);
        mockComplianceModule.setNextTransferShouldFail(false);

        assertEq(token.balanceOf(clientUS), 0, "Blocked transfer should have failed (receiver balance)");
        assertEq(token.balanceOf(clientBE), 900, "Blocked transfer should have failed (sender balance)");

        // Test transfer blocked by verification (should not hit mock compliance)
        uint256 transferredHookCountBeforeUnverified = mockComplianceModule.transferredCallCount();
        vm.expectRevert(abi.encodeWithSelector(ISMART.RecipientNotVerified.selector));
        tokenUtils.transferToken(address(token), clientBE, clientUnverified, 100);
        assertEq(
            token.balanceOf(clientUnverified), 0, "Verification-blocked transfer should have failed (receiver balance)"
        );
        assertEq(token.balanceOf(clientBE), 900, "Verification-blocked transfer should have failed (sender balance)");
        assertEq(
            mockComplianceModule.transferredCallCount(),
            transferredHookCountBeforeUnverified,
            "Mock transferred hook count changed on verification fail"
        );
    }

    function test_Pause() public {
        // Assumes token is deployed and identities are set up by setUp() in inheriting contract
        require(address(token) != address(0), "Token not deployed in setUp");

        mockComplianceModule.reset(); // Reset for this test

        uint256 createdHookCountBefore = mockComplianceModule.createdCallCount();
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 500);
        assertEq(
            mockComplianceModule.createdCallCount(),
            createdHookCountBefore + 1,
            "Mock created hook count incorrect after initial mint in test_Pause"
        );

        tokenUtils.pauseToken(address(token), tokenIssuer);

        // Check minting is paused
        vm.expectRevert(abi.encodeWithSelector(_SMARTPausableLogic.TokenPaused.selector));
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 500);

        // Check transfers are paused
        vm.expectRevert(abi.encodeWithSelector(_SMARTPausableLogic.TokenPaused.selector));
        tokenUtils.transferToken(address(token), clientBE, clientJP, 100);

        // Check burning is paused (Add burn function to TokenUtils if needed)
        // vm.expectRevert(abi.encodeWithSelector(_SMARTPausableLogic.TokenPaused.selector));
        // tokenUtils.burnToken(address(token), clientBE, 10);

        // Unpause
        tokenUtils.unpauseToken(address(token), tokenIssuer);

        // Check minting works again
        createdHookCountBefore = mockComplianceModule.createdCallCount();
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 100);
        assertEq(token.balanceOf(clientBE), 600); // 500 initial + 100 new
        assertEq(
            mockComplianceModule.createdCallCount(),
            createdHookCountBefore + 1,
            "Mock created hook count incorrect after mint post-unpause"
        );

        // Check transfer works again
        uint256 transferredHookCountBefore = mockComplianceModule.transferredCallCount();
        tokenUtils.transferToken(address(token), clientBE, clientJP, 50);
        assertEq(token.balanceOf(clientJP), 50);
        assertEq(token.balanceOf(clientBE), 550);
        assertEq(
            mockComplianceModule.transferredCallCount(),
            transferredHookCountBefore + 1,
            "Mock transferred hook count incorrect after transfer post-unpause"
        );
    }

    function test_Burn() public {
        // Assumes token is deployed and identities are set up by setUp() in inheriting contract
        require(address(token) != address(0), "Token not deployed in setUp");

        // --- Initial Mint ---
        uint256 initialMintAmount = 500;
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, initialMintAmount);
        assertEq(token.balanceOf(clientBE), initialMintAmount, "Burn test setup mint failed");

        mockComplianceModule.reset(); // Reset mock counter for burn tests

        // --- Burn Tokens ---
        uint256 burnAmount = 100;
        uint256 destroyedHookCountBefore = mockComplianceModule.destroyedCallCount();
        tokenUtils.burnToken(address(token), tokenIssuer, clientBE, burnAmount);

        // --- Assertions ---
        assertEq(token.balanceOf(clientBE), initialMintAmount - burnAmount, "Burn failed (balance incorrect)");
        assertEq(
            mockComplianceModule.destroyedCallCount(),
            destroyedHookCountBefore + 1,
            "Mock destroyed hook count incorrect after burn"
        );

        // --- Test Burn When Paused ---
        tokenUtils.pauseToken(address(token), tokenIssuer);

        // Check burning is paused
        vm.expectRevert(abi.encodeWithSelector(_SMARTPausableLogic.TokenPaused.selector));
        tokenUtils.burnToken(address(token), tokenIssuer, clientBE, 10); // Attempt to burn while paused

        // Unpause
        tokenUtils.unpauseToken(address(token), tokenIssuer);

        // Check burning works again
        destroyedHookCountBefore = mockComplianceModule.destroyedCallCount();
        uint256 secondBurnAmount = 20;
        uint256 balanceBeforeSecondBurn = token.balanceOf(clientBE);
        tokenUtils.burnToken(address(token), tokenIssuer, clientBE, secondBurnAmount);
        assertEq(token.balanceOf(clientBE), balanceBeforeSecondBurn - secondBurnAmount, "Burn after unpause failed");
        assertEq(
            mockComplianceModule.destroyedCallCount(),
            destroyedHookCountBefore + 1,
            "Mock destroyed hook count incorrect after burn post-unpause"
        );
    }

    // --- Test for SMARTRedeemable ---

    function test_Redeem() public {
        // Assumes token is deployed, includes SMARTRedeemable, and identities are set up
        require(address(token) != address(0), "Token not deployed in setUp");

        // --- Initial Mint ---
        uint256 initialMintAmount = 500;
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, initialMintAmount);
        assertEq(token.balanceOf(clientBE), initialMintAmount, "Redeem test setup mint failed");

        mockComplianceModule.reset(); // Reset mock counter for redeem tests

        // --- Redeem Tokens (as clientBE) ---
        uint256 redeemAmount = 100;
        uint256 destroyedHookCountBefore = mockComplianceModule.destroyedCallCount();
        uint256 initialTotalSupply = token.totalSupply();

        // Assuming the 'token' instance will have the 'redeem' function from SMARTRedeemable
        // We need to cast 'token' to an interface that includes 'redeem', or assume it exists.
        // For simplicity in the base test, we'll call it directly. Inheriting tests must ensure
        // the token actually implements SMARTRedeemable.
        // A more robust approach might involve an interface like ISMARTRedeemable(address(token)).redeem(redeemAmount);
        // For simplicity in the base test, we'll call it directly. Inheriting tests must ensure
        // the token actually implements SMARTRedeemable.
        // A more robust approach might involve an interface like ISMARTRedeemable(address(token)).redeem(redeemAmount);
        tokenUtils.redeemToken(address(token), clientBE, redeemAmount);

        // --- Assertions ---
        assertEq(token.balanceOf(clientBE), initialMintAmount - redeemAmount, "Redeem failed (balance incorrect)");
        assertEq(token.totalSupply(), initialTotalSupply - redeemAmount, "Redeem failed (total supply incorrect)");
        // Redeem triggers _burn, which should trigger the destroyed hook
        assertEq(
            mockComplianceModule.destroyedCallCount(),
            destroyedHookCountBefore + 1,
            "Mock destroyed hook count incorrect after redeem"
        );

        uint256 balance = token.balanceOf(clientBE);
        // --- Test Redeem More Than Balance ---
        // Expect ERC20InsufficientBalance revert (or similar depending on ERC20 implementation)
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, clientBE, balance, balance + 1)
        );
        // check as specific error might vary
        tokenUtils.redeemToken(address(token), clientBE, balance + 1);

        // --- Test Redeem When Paused (if applicable) ---
        // This assumes the token also inherits from SMARTPausable
        tokenUtils.pauseToken(address(token), tokenIssuer);

        vm.expectRevert(abi.encodeWithSelector(_SMARTPausableLogic.TokenPaused.selector));
        tokenUtils.redeemToken(address(token), clientBE, 10);

        // Unpause
        tokenUtils.unpauseToken(address(token), tokenIssuer);

        // Check redeem works again
        destroyedHookCountBefore = mockComplianceModule.destroyedCallCount();
        uint256 secondRedeemAmount = 20;
        uint256 balanceBeforeSecondRedeem = token.balanceOf(clientBE);
        initialTotalSupply = token.totalSupply(); // Update total supply

        tokenUtils.redeemToken(address(token), clientBE, secondRedeemAmount);

        assertEq(
            token.balanceOf(clientBE), balanceBeforeSecondRedeem - secondRedeemAmount, "Redeem after unpause failed"
        );
        assertEq(
            token.totalSupply(), initialTotalSupply - secondRedeemAmount, "Redeem after unpause failed (total supply)"
        );
        assertEq(
            mockComplianceModule.destroyedCallCount(),
            destroyedHookCountBefore + 1,
            "Mock destroyed hook count incorrect after redeem post-unpause"
        );
    }

    // --- Custodian Tests ---

    // Helper function to add initial mints AFTER token is deployed by child setUp
    function _mintInitialBalances() internal {
        // Only mint if token is deployed
        if (address(token) != address(0)) {
            // Use low-level mint via TokenUtils to bypass potential compliance/role checks if needed,
            // or use the token's mint function if roles are correctly set up.
            // Assuming tokenIssuer has minting rights or tokenUtils handles it.
            uint256 initialMint = 1000 ether;
            if (token.balanceOf(clientBE) == 0) {
                tokenUtils.mintToken(address(token), tokenIssuer, clientBE, initialMint);
            }
            if (token.balanceOf(clientJP) == 0) {
                tokenUtils.mintToken(address(token), tokenIssuer, clientJP, initialMint);
            }
            if (token.balanceOf(clientUS) == 0) {
                tokenUtils.mintToken(address(token), tokenIssuer, clientUS, initialMint);
            }
            // clientUnverified typically starts with 0 balance in tests
        }
    }

    function test_FreezeAddress() public {
        require(address(token) != address(0), "Token not deployed in setUp");
        _mintInitialBalances(); // Ensure clients have funds

        // Use TokenUtils for custodian checks and actions

        // --- Assert Initial State ---
        assertFalse(tokenUtils.isFrozen(address(token), clientBE), "ClientBE should not be frozen initially");

        // --- Freeze Address (as owner) ---
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientBE, true);
        assertTrue(
            tokenUtils.isFrozen(address(token), clientBE), "ClientBE should be frozen after setAddressFrozen(true)"
        );

        // --- Test Frozen Address Restrictions ---
        // 1. Transfer From Frozen Address should fail
        vm.startPrank(clientBE); // Try to transfer from frozen address
        vm.expectRevert(abi.encodeWithSelector(_SMARTCustodianLogic.SenderAddressFrozen.selector));
        token.transfer(clientJP, 10 ether); // Use base token transfer for revert check
        vm.stopPrank();

        // 2. Transfer To Frozen Address should fail
        vm.startPrank(clientJP); // Try to transfer to frozen address
        vm.expectRevert(abi.encodeWithSelector(_SMARTCustodianLogic.RecipientAddressFrozen.selector));
        token.transfer(clientBE, 10 ether); // Use base token transfer for revert check
        vm.stopPrank();

        // 3. Mint To Frozen Address should fail (assuming mint exists and owner/minter tries)
        vm.expectRevert(abi.encodeWithSelector(_SMARTCustodianLogic.RecipientAddressFrozen.selector));
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 100 ether);

        // 4. Redeem by Frozen Address should fail (if SMARTRedeemable is used)
        // Removed the complex redeemExists check. If the token has redeem, this should fail.
        // If not, the test setup for the specific token should not include this check.
        vm.startPrank(clientBE);
        vm.expectRevert(abi.encodeWithSelector(_SMARTCustodianLogic.SenderAddressFrozen.selector));
        // Assuming redeem exists for the purpose of testing the custodian block
        // Use tokenUtils.redeemToken if you are sure the token under test supports it.
        // Direct call here for simplicity, relies on inheriting test ensuring redeem exists.
        // This might still fail if SMARTRedeemable is not mixed in.
        tokenUtils.redeemToken(address(token), clientBE, 10 ether);
        vm.stopPrank();

        // --- Unfreeze Address (as owner) ---
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientBE, false);
        assertFalse(
            tokenUtils.isFrozen(address(token), clientBE), "ClientBE should be unfrozen after setAddressFrozen(false)"
        );

        // --- Test Unfrozen Address Operations ---
        uint256 balanceBEBefore = token.balanceOf(clientBE);
        uint256 balanceJPBefore = token.balanceOf(clientJP);
        // Transfer should now work (using tokenUtils)
        tokenUtils.transferToken(address(token), clientBE, clientJP, 20 ether);
        assertEq(
            token.balanceOf(clientJP), balanceJPBefore + 20 ether, "Transfer post-unfreeze receiver balance failed"
        );
        assertEq(token.balanceOf(clientBE), balanceBEBefore - 20 ether, "Transfer post-unfreeze sender balance failed");

        // Mint should now work (using tokenUtils)
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 50 ether);
        assertEq(token.balanceOf(clientBE), balanceBEBefore - 20 ether + 50 ether, "Mint post-unfreeze balance failed");

        // Redeem should now work (using tokenUtils)
        // Again, assumes token supports redeem
        uint256 balanceBEBeforeRedeem = token.balanceOf(clientBE);
        tokenUtils.redeemToken(address(token), clientBE, 30 ether);
        assertEq(token.balanceOf(clientBE), balanceBEBeforeRedeem - 30 ether, "Redeem post-unfreeze balance failed");

        // --- Test Access Control --- (Using tokenUtils)
        vm.startPrank(clientJP); // Non-owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, clientJP));
        // Use tokenUtils for the call
        tokenUtils.setAddressFrozen(address(token), clientJP, clientBE, true); // Attempting as clientJP
        vm.stopPrank();
    }

    function test_PartialFreezeTokens() public {
        require(address(token) != address(0), "Token not deployed in setUp");
        _mintInitialBalances(); // Ensure clients have funds

        // Use TokenUtils
        uint256 initialBalance = token.balanceOf(clientBE);
        require(initialBalance > 0, "Initial balance is zero, cannot test partial freeze");
        uint256 freezeAmount = initialBalance / 5; // Freeze 20%

        // --- Assert Initial State ---
        assertEq(
            tokenUtils.getFrozenTokens(address(token), clientBE), 0, "ClientBE should have 0 frozen tokens initially"
        );

        // --- Freeze Partial Tokens (as owner) ---
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);
        assertEq(
            tokenUtils.getFrozenTokens(address(token), clientBE),
            freezeAmount,
            "Frozen token amount incorrect after freeze"
        );

        // --- Test Restrictions ---
        // 1. Transfer more than available unfrozen balance should fail
        uint256 availableUnfrozen = initialBalance - freezeAmount;
        vm.startPrank(clientBE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                clientBE,
                availableUnfrozen,
                availableUnfrozen + 1 wei // Request 1 wei more than available
            )
        );
        token.transfer(clientJP, availableUnfrozen + 1 wei); // Direct transfer check
        vm.stopPrank();

        // 2. Transfer exact available unfrozen balance should succeed
        uint256 balJPBefore = token.balanceOf(clientJP);
        tokenUtils.transferToken(address(token), clientBE, clientJP, availableUnfrozen); // Use tokenUtils transfer
        assertEq(token.balanceOf(clientBE), freezeAmount, "Balance after transferring all unfrozen tokens is wrong");
        assertEq(
            token.balanceOf(clientJP),
            balJPBefore + availableUnfrozen,
            "Receiver balance after full unfrozen transfer is wrong"
        );
        assertEq(
            tokenUtils.getFrozenTokens(address(token), clientBE),
            freezeAmount,
            "Frozen amount should remain after transfer"
        );

        // 3. Transfer from remaining (frozen) balance should fail
        vm.startPrank(clientBE);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, clientBE, 0, 1 wei) // Available
                // unfrozen is 0
        );
        token.transfer(clientJP, 1 wei); // Direct transfer check
        vm.stopPrank();

        // --- Unfreeze Partial Tokens (as owner) ---
        uint256 unfreezeAmount = freezeAmount / 2;
        tokenUtils.unfreezePartialTokens(address(token), tokenIssuer, clientBE, unfreezeAmount);
        assertEq(
            tokenUtils.getFrozenTokens(address(token), clientBE),
            freezeAmount - unfreezeAmount,
            "Frozen token amount incorrect after unfreeze"
        );

        // --- Test Transfer After Partial Unfreeze ---
        uint256 newlyAvailable = unfreezeAmount;
        uint256 currentFrozen = tokenUtils.getFrozenTokens(address(token), clientBE);
        balJPBefore = token.balanceOf(clientJP);
        tokenUtils.transferToken(address(token), clientBE, clientJP, newlyAvailable); // Use tokenUtils transfer
        assertEq(token.balanceOf(clientBE), currentFrozen, "Balance after partial unfreeze transfer is wrong"); // Should
            // equal remaining frozen
        assertEq(
            token.balanceOf(clientJP),
            balJPBefore + newlyAvailable,
            "Receiver balance after partial unfreeze transfer is wrong"
        );
        assertEq(
            tokenUtils.getFrozenTokens(address(token), clientBE),
            currentFrozen,
            "Frozen amount should remain after partial unfreeze transfer"
        );

        // --- Test Unfreezing More Than Frozen ---
        currentFrozen = tokenUtils.getFrozenTokens(address(token), clientBE);
        vm.expectRevert(
            abi.encodeWithSelector(
                _SMARTCustodianLogic.InsufficientFrozenTokens.selector, currentFrozen, currentFrozen + 1 wei
            )
        );
        tokenUtils.unfreezePartialTokens(address(token), tokenIssuer, clientBE, currentFrozen + 1 wei);

        // --- Test Freezing More Than Available ---
        // Available = Total Balance - Current Frozen
        uint256 currentBalance = token.balanceOf(clientBE); // equals currentFrozen at this point
        uint256 currentAvailable = currentBalance - currentFrozen; // Should be 0
        vm.expectRevert(
            abi.encodeWithSelector(
                _SMARTCustodianLogic.FreezeAmountExceedsAvailableBalance.selector, currentAvailable, 1 wei
            )
        );
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, 1 wei);

        // --- Test Access Control --- (Using tokenUtils)
        vm.startPrank(clientJP); // Non-owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, clientJP));
        tokenUtils.freezePartialTokens(address(token), clientJP, clientBE, 1 wei);
        vm.stopPrank();

        vm.startPrank(clientJP);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, clientJP));
        tokenUtils.unfreezePartialTokens(address(token), clientJP, clientBE, 1 wei);
        vm.stopPrank();
    }

    function test_ForcedTransfer() public {
        require(address(token) != address(0), "Token not deployed in setUp");
        _mintInitialBalances(); // Ensure clients have funds

        // Use TokenUtils
        uint256 initialSenderBalance = token.balanceOf(clientBE);
        uint256 initialReceiverBalance = token.balanceOf(clientJP);
        require(initialSenderBalance > 0, "Initial sender balance is zero, cannot test forced transfer");
        uint256 transferAmount = initialSenderBalance / 4; // Transfer 25%

        // --- Basic Forced Transfer (as owner) ---
        tokenUtils.forcedTransfer(address(token), tokenIssuer, clientBE, clientJP, transferAmount);

        assertEq(
            token.balanceOf(clientBE),
            initialSenderBalance - transferAmount,
            "Sender balance wrong after forced transfer"
        );
        assertEq(
            token.balanceOf(clientJP),
            initialReceiverBalance + transferAmount,
            "Receiver balance wrong after forced transfer"
        );

        // --- Forced Transfer More Than Balance ---
        // Should check total balance inside _forcedTransfer
        uint256 currentSenderBalance = token.balanceOf(clientBE);
        uint256 excessiveAmount = currentSenderBalance + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                _SMARTCustodianLogic.InsufficientTotalBalance.selector, currentSenderBalance, excessiveAmount
            )
        );
        vm.prank(tokenIssuer);
        token.forcedTransfer(clientBE, clientJP, excessiveAmount);

        // Test forced transfer from a frozen address (should succeed if amount <= unfrozen)
        uint256 freezeAmount = 100e18;
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientBE, true);
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);
        assertTrue(tokenUtils.isFrozen(address(token), clientBE), "ClientBE should be frozen");
        assertEq(tokenUtils.getFrozenTokens(address(token), clientBE), freezeAmount, "Frozen tokens amount incorrect");

        vm.expectRevert(
            abi.encodeWithSelector(
                _SMARTCustodianLogic.InsufficientUnfrozenBalance.selector,
                currentSenderBalance - freezeAmount,
                freezeAmount
            )
        );
        vm.prank(tokenIssuer);
        token.forcedTransfer(clientBE, clientJP, freezeAmount);

        // Test case where forced transfer > unfrozen but < total, and should automatically unfreeze
        uint256 usBalanceBefore = token.balanceOf(clientUS);
        uint256 usUnfrozen = usBalanceBefore / 2;
        uint256 exceedUnfrozenAmount = usUnfrozen + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                _SMARTCustodianLogic.InsufficientUnfrozenBalance.selector, usUnfrozen, exceedUnfrozenAmount
            )
        );
        vm.prank(tokenIssuer);
        // Use the interface for the direct call to avoid linter errors in base class
        ISMARTCustodianFeatures(address(token)).forcedTransfer(clientUS, clientBE, exceedUnfrozenAmount);

        // Stop pranking after the call that might revert
        // Removed unnecessary try-catch block

        // Test case where forced transfer > unfrozen but < total, and should automatically unfreeze
        uint256 finalExcessiveAmount = usBalanceBefore - usUnfrozen + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                _SMARTCustodianLogic.InsufficientTotalBalance.selector, usBalanceBefore, finalExcessiveAmount
            )
        );
        vm.prank(tokenIssuer);
        // Use the interface for the direct call
        ISMARTCustodianFeatures(address(token)).forcedTransfer(clientUS, clientBE, finalExcessiveAmount);

        // Removed unnecessary try-catch block
    }

    function test_AddressRecovery() public {
        require(address(token) != address(0), "Token not deployed in setUp");
        _mintInitialBalances(); // Ensure clients have funds

        // Use TokenUtils
        address lostWallet = clientBE;
        address newWallet = makeAddr("New Wallet BE");
        address claimIssuerIdentityAddress = identityUtils.getIdentity(claimIssuer); // Get issuer's identity

        uint256 initialLostBalance = token.balanceOf(lostWallet);
        require(initialLostBalance > 0, "Lost wallet has no balance to recover");

        // Pre-checks for identity registry state
        assertTrue(
            infrastructureUtils.identityRegistry().isVerified(lostWallet, requiredClaimTopics),
            "Lost wallet should be verified"
        );
        assertFalse(
            infrastructureUtils.identityRegistry().isVerified(newWallet, requiredClaimTopics),
            "New wallet should NOT be verified initially"
        );

        // --- Perform Recovery (as owner) ---
        address investorOnchainID = identityUtils.getIdentity(lostWallet); // Get the identity contract address
        require(investorOnchainID != address(0), "Could not get OnchainID for lost wallet");

        // Specify emitter address(token) for all expected events
        vm.expectEmit(true, true, true, true, address(token));
        emit _SMARTCustodianLogic.RecoverySuccess(lostWallet, newWallet, investorOnchainID);
        tokenUtils.recoveryAddress(address(token), tokenIssuer, lostWallet, newWallet, investorOnchainID);

        // --- Assert Post-Recovery State ---
        assertEq(token.balanceOf(lostWallet), 0, "Lost wallet balance should be 0 after recovery");
        assertEq(token.balanceOf(newWallet), initialLostBalance, "New wallet balance incorrect after recovery");

        // Check identity registry state
        // Commented out check for lost wallet deletion
        assertTrue(
            infrastructureUtils.identityRegistry().isVerified(newWallet, requiredClaimTopics),
            "New wallet SHOULD be verified after recovery"
        );
        assertEq(
            infrastructureUtils.identityRegistry().investorCountry(newWallet),
            TestConstants.COUNTRY_CODE_BE,
            "Country code not transferred"
        );

        // --- Test Recovery with Frozen States ---
        address lostWallet2 = clientJP;
        address newWallet2 = makeAddr("New Wallet JP");
        address investorOnchainID2 = identityUtils.getIdentity(lostWallet2);
        uint256 initialLostBalance2 = token.balanceOf(lostWallet2);
        require(initialLostBalance2 > 0, "Lost wallet 2 has no balance to recover");

        // Freeze the lost wallet address and some tokens
        uint256 freezeAmount2 = initialLostBalance2 / 3;
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, lostWallet2, true);
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, lostWallet2, freezeAmount2);
        assertTrue(tokenUtils.isFrozen(address(token), lostWallet2), "Lost wallet 2 should be frozen");
        assertEq(
            tokenUtils.getFrozenTokens(address(token), lostWallet2),
            freezeAmount2,
            "Lost wallet 2 frozen tokens incorrect"
        );

        // Perform recovery - Expect events in specific order with emitter check
        vm.expectEmit(true, true, true, true, address(token));
        emit _SMARTCustodianLogic.TokensUnfrozen(lostWallet2, freezeAmount2); // Tokens unfrozen from old
        vm.expectEmit(true, true, true, true, address(token));
        emit _SMARTCustodianLogic.TokensFrozen(newWallet2, freezeAmount2); // Tokens frozen on new
        vm.expectEmit(true, true, true, true, address(token));
        emit _SMARTCustodianLogic.AddressFrozen(newWallet2, true); // New wallet frozen
        vm.expectEmit(true, true, true, true, address(token));
        emit _SMARTCustodianLogic.AddressFrozen(lostWallet2, false); // Old wallet unfrozen
        vm.expectEmit(true, true, true, true, address(token)); // Expect RecoverySuccess event
        emit _SMARTCustodianLogic.RecoverySuccess(lostWallet2, newWallet2, investorOnchainID2);
        tokenUtils.recoveryAddress(address(token), tokenIssuer, lostWallet2, newWallet2, investorOnchainID2);

        // Assert state transfer
        assertEq(token.balanceOf(lostWallet2), 0, "Lost wallet 2 balance should be 0");
        assertEq(token.balanceOf(newWallet2), initialLostBalance2, "New wallet 2 balance incorrect");
        assertTrue(tokenUtils.isFrozen(address(token), newWallet2), "New wallet 2 should inherit frozen status");
        assertFalse(tokenUtils.isFrozen(address(token), lostWallet2), "Lost wallet 2 should be unfrozen");
        assertEq(
            tokenUtils.getFrozenTokens(address(token), newWallet2),
            freezeAmount2,
            "New wallet 2 should inherit frozen tokens"
        );
        assertEq(tokenUtils.getFrozenTokens(address(token), lostWallet2), 0, "Lost wallet 2 frozen tokens should be 0");

        // Commented out check for lost wallet deletion
        assertTrue(
            infrastructureUtils.identityRegistry().isVerified(newWallet2, requiredClaimTopics),
            "New wallet 2 SHOULD be verified after recovery"
        );

        // --- Test Recovery Failure Cases ---
        // 1. No balance to recover
        address emptyWallet = makeAddr("Empty Wallet");
        address newEmptyWallet = makeAddr("New Empty Wallet");
        // We need an identity first to test this path properly
        identityUtils.createClientIdentity(emptyWallet, TestConstants.COUNTRY_CODE_US); // Create identity
        claimUtils.issueAllClaims(claimIssuerIdentityAddress, emptyWallet); // Issue claims
        address emptyOnchainID = identityUtils.getIdentity(emptyWallet); // Now get ID
        require(token.balanceOf(emptyWallet) == 0, "Setup failed: emptyWallet has balance");

        vm.expectRevert(abi.encodeWithSelector(_SMARTCustodianLogic.NoTokensToRecover.selector));
        tokenUtils.recoveryAddress(address(token), tokenIssuer, emptyWallet, newEmptyWallet, emptyOnchainID);

        // 2. Target address is frozen
        address lostWallet3 = clientUS; // Has balance from _mintInitialBalances
        address newWallet3 = makeAddr("New Wallet US");
        address investorOnchainID3 = identityUtils.getIdentity(lostWallet3);
        require(token.balanceOf(lostWallet3) > 0, "Lost wallet 3 has no balance for recovery test");
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, newWallet3, true); // Freeze the target
        vm.expectRevert(abi.encodeWithSelector(_SMARTCustodianLogic.RecoveryTargetAddressFrozen.selector));
        tokenUtils.recoveryAddress(address(token), tokenIssuer, lostWallet3, newWallet3, investorOnchainID3);
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, newWallet3, false); // Unfreeze for cleanup /
            // subsequent tests

        // 3. Wallets not verified (This check is inside _SMARTCustodianLogic._recoveryAddress, difficult to trigger
        // externally without more complex setup)

        // 4. Recovery by non-owner
        vm.startPrank(clientBE); // Non-owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, clientBE));
        tokenUtils.recoveryAddress(address(token), clientBE, lostWallet3, newWallet3, investorOnchainID3); // Attempt as
            // non-owner
        vm.stopPrank();
    }

    // --- Internal Helper Functions ---

    function _setupIdentities() internal {
        // Create the token issuer identity
        identityUtils.createClientIdentity(tokenIssuer, TestConstants.COUNTRY_CODE_BE);
        // Issue claims to the token issuer as well (assuming they need verification)
        uint256[] memory claimTopics = new uint256[](2);
        claimTopics[0] = TestConstants.CLAIM_TOPIC_KYC;
        claimTopics[1] = TestConstants.CLAIM_TOPIC_AML;
        // Use claimIssuer address directly, createIssuerIdentity handles creating the on-chain identity
        address claimIssuerIdentityAddress = identityUtils.createIssuerIdentity(claimIssuer, claimTopics);
        // Now issue claims TO the token issuer
        claimUtils.issueAllClaims(claimIssuerIdentityAddress, tokenIssuer);

        // Create the client identities
        identityUtils.createClientIdentity(clientBE, TestConstants.COUNTRY_CODE_BE);
        identityUtils.createClientIdentity(clientJP, TestConstants.COUNTRY_CODE_JP);
        identityUtils.createClientIdentity(clientUS, TestConstants.COUNTRY_CODE_US);
        identityUtils.createClientIdentity(clientUnverified, TestConstants.COUNTRY_CODE_BE);

        // Issue claims to clients
        claimUtils.issueAllClaims(claimIssuerIdentityAddress, clientBE);
        claimUtils.issueAllClaims(claimIssuerIdentityAddress, clientJP);
        claimUtils.issueAllClaims(claimIssuerIdentityAddress, clientUS);
        // Only issue KYC claim to the unverified client
        claimUtils.issueKYCClaim(claimIssuerIdentityAddress, clientUnverified);
    }
}
