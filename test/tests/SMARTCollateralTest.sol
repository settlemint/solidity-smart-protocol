// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TestConstants } from "./Constants.sol";
import { SMARTTest } from "./SMARTTest.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
import { ClaimUtils } from "./utils/ClaimUtils.sol";
import { ISMART } from "../../contracts/interface/ISMART.sol";
import { InsufficientCollateral } from "../../contracts/extensions/collateral/SMARTCollateralErrors.sol";

abstract contract SMARTCollateralTest is SMARTTest {
    uint256 internal constant COLLATERAL_AMOUNT = 1_000_000 ether; // Example collateral amount
    uint256 internal constant MINT_AMOUNT = 100 ether;

    // --- Test Cases ---

    function test_Mint_Success_WithValidCollateralClaim() public {
        // 1. Issue a valid collateral claim to the token's identity
        address tokenIdentityAddr = _getTokenIdentityAddress();
        uint256 expiry = block.timestamp + 1 days;
        claimUtils.issueCollateralClaim(tokenIdentityAddr, tokenIssuer, COLLATERAL_AMOUNT, expiry);

        // 2. Mint tokens (amount <= collateral)
        // _mintInitialBalances(); // Avoid calling this here as it might interfere with collateral logic
        uint256 initialSupply = token.totalSupply();
        require(initialSupply + MINT_AMOUNT <= COLLATERAL_AMOUNT, "Test setup error: mint amount exceeds collateral");

        uint256 balBESnap = token.balanceOf(clientBE);
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, MINT_AMOUNT); // Using TokenUtils for consistency

        // 3. Verify mint succeeded
        assertEq(token.balanceOf(clientBE), balBESnap + MINT_AMOUNT, "Balance wrong after mint");
        assertEq(token.totalSupply(), initialSupply + MINT_AMOUNT, "Total supply wrong after mint");
    }

    function test_Mint_Fail_InsufficientCollateral() public {
        // 1. Issue a collateral claim with an amount LESS than the intended mint amount
        address tokenIdentityAddr = _getTokenIdentityAddress();
        uint256 insufficientCollateral = MINT_AMOUNT / 2;
        uint256 expiry = block.timestamp + 1 days;
        claimUtils.issueCollateralClaim(tokenIdentityAddr, tokenIssuer, insufficientCollateral, expiry);

        // 2. Attempt to mint tokens (amount > collateral)
        uint256 currentSupply = token.totalSupply(); // Could be 0
        uint256 requiredSupply = currentSupply + MINT_AMOUNT;

        vm.expectRevert(abi.encodeWithSelector(InsufficientCollateral.selector, requiredSupply, insufficientCollateral));
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, MINT_AMOUNT);
    }

    function test_Mint_Success_MultipleMintsWithinLimit() public {
        // 1. Issue a valid collateral claim
        address tokenIdentityAddr = _getTokenIdentityAddress();
        uint256 expiry = block.timestamp + 1 days;
        claimUtils.issueCollateralClaim(tokenIdentityAddr, tokenIssuer, COLLATERAL_AMOUNT, expiry);

        // 2. Mint first batch
        uint256 mintAmount1 = COLLATERAL_AMOUNT / 4;
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, mintAmount1);
        uint256 supplyAfter1 = token.totalSupply();
        assertEq(supplyAfter1, mintAmount1, "Supply 1 mismatch");

        // 3. Mint second batch (total <= collateral)
        uint256 mintAmount2 = COLLATERAL_AMOUNT / 4;
        require(supplyAfter1 + mintAmount2 <= COLLATERAL_AMOUNT, "Test setup error: mint 2 exceeds collateral");
        tokenUtils.mintToken(address(token), tokenIssuer, clientJP, mintAmount2); // Mint to different client
        uint256 supplyAfter2 = token.totalSupply();
        assertEq(supplyAfter2, supplyAfter1 + mintAmount2, "Supply 2 mismatch");
    }

    function test_Mint_Fail_MultipleMintsExceedLimit() public {
        // 1. Issue a valid collateral claim
        address tokenIdentityAddr = _getTokenIdentityAddress();
        uint256 specificCollateral = 500 ether;
        uint256 expiry = block.timestamp + 1 days;
        claimUtils.issueCollateralClaim(tokenIdentityAddr, tokenIssuer, specificCollateral, expiry);

        // 2. Mint first batch (within limit)
        uint256 mintAmount1 = specificCollateral / 2;
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, mintAmount1);
        uint256 supplyAfter1 = token.totalSupply();

        // 3. Attempt to mint second batch (total > collateral)
        uint256 mintAmount2 = specificCollateral / 2 + 1 ether; // Exceeds limit
        uint256 requiredSupply = supplyAfter1 + mintAmount2;

        vm.expectRevert(abi.encodeWithSelector(InsufficientCollateral.selector, requiredSupply, specificCollateral));
        tokenUtils.mintToken(address(token), tokenIssuer, clientJP, mintAmount2);
    }

    function test_Mint_Fail_ExpiredCollateralClaim() public {
        // 1. Issue a collateral claim with an expiry in the past
        address tokenIdentityAddr = _getTokenIdentityAddress();
        uint256 pastExpiry = block.timestamp - 1 days; // Expired
        claimUtils.issueCollateralClaim(tokenIdentityAddr, tokenIssuer, COLLATERAL_AMOUNT, pastExpiry);

        // 2. Attempt to mint tokens
        uint256 currentSupply = token.totalSupply();
        uint256 requiredSupply = currentSupply + MINT_AMOUNT;

        // Expect revert because findValidCollateralClaim returns 0 for expired claims
        vm.expectRevert(
            abi.encodeWithSelector(InsufficientCollateral.selector, requiredSupply, 0) // Available collateral is 0
        );
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, MINT_AMOUNT);
    }

    function test_Mint_Fail_NoCollateralClaim() public {
        // 1. Do NOT issue any collateral claim

        // 2. Attempt to mint tokens
        uint256 currentSupply = token.totalSupply();
        uint256 requiredSupply = currentSupply + MINT_AMOUNT;

        // Expect revert because findValidCollateralClaim returns 0
        vm.expectRevert(
            abi.encodeWithSelector(InsufficientCollateral.selector, requiredSupply, 0) // Available collateral is 0
        );
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, MINT_AMOUNT);
    }

    function test_Mint_Fail_UntrustedIssuer() public {
        // 1. Setup an untrusted issuer
        address untrustedIssuerWallet = makeAddr("untrustedIssuerWallet");
        uint256 untrustedIssuerPK = 0xBAD155;
        vm.label(untrustedIssuerWallet, "Untrusted Issuer Wallet");

        // Deploy identity for the untrusted issuer

        // Deploy identity + add management key controlled by the wallet itself
        vm.prank(platformAdmin);
        address untrustedIssuerIdentityAddr = identityUtils.createIdentity(untrustedIssuerWallet);
        vm.label(untrustedIssuerIdentityAddr, "Untrusted Issuer Identity");

        // Create a temporary ClaimUtils for the untrusted issuer
        ClaimUtils untrustedClaimUtils = new ClaimUtils(
            platformAdmin,
            untrustedIssuerWallet,
            untrustedIssuerPK,
            infrastructureUtils.identityRegistry(),
            infrastructureUtils.identityFactory()
        );

        address tokenIdentityAddr = _getTokenIdentityAddress();
        uint256 expiry = block.timestamp + 1 days;

        // Create the claim signature using the untrusted utils
        untrustedClaimUtils.issueCollateralClaim(tokenIdentityAddr, tokenIssuer, COLLATERAL_AMOUNT, expiry);

        // 3. Attempt to mint tokens
        uint256 currentSupply = token.totalSupply();
        uint256 requiredSupply = currentSupply + MINT_AMOUNT;

        // Expect revert because the issuer (untrustedIssuerIdentityAddr) isn't in the trusted list for COLLATERAL_TOPIC
        // findValidCollateralClaim will iterate issuers, find the claim, but see it's not from a trusted source for the
        // topic.
        vm.expectRevert(
            abi.encodeWithSelector(InsufficientCollateral.selector, requiredSupply, 0) // Available collateral is 0
        );
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, MINT_AMOUNT);
    }

    // Helper to get token identity address
    function _getTokenIdentityAddress() internal view returns (address) {
        // Cast token to SMART to access onchainID()
        // Ensure 'token' is the correct variable holding the deployed SMART token instance
        return ISMART(payable(address(token))).onchainID();
    }
}
