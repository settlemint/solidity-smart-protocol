// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { MySMARTTokenFactory } from "../../contracts/MySMARTTokenFactory.sol";
import { MySMARTToken } from "../../contracts/MySMARTToken.sol";
import { SMARTIdentityFactory } from "../../contracts/SMART/SMARTIdentityFactory.sol";
import { SMARTCompliance } from "../../contracts/SMART/SMARTCompliance.sol";
import { ISMART } from "../../contracts/SMART/interface/ISMART.sol";

contract TokenUtils is Test {
    address internal _platformAdmin;
    SMARTIdentityFactory internal _identityFactory;
    SMARTCompliance internal _compliance; // Reference if needed, though factory uses it

    constructor(
        address platformAdmin_,
        SMARTIdentityFactory identityFactory_,
        SMARTCompliance compliance_ // Pass compliance even if factory uses it, might be needed elsewhere
    ) {
        _platformAdmin = platformAdmin_;
        _identityFactory = identityFactory_;
        _compliance = compliance_;
    }

    /**
     * @notice Creates a new SMART token using a specified factory.
     * @param tokenFactory The factory instance (e.g., bondFactory, equityFactory) to use.
     * @param name The token name.
     * @param symbol The token symbol.
     * @param claimTopics Required claim topics for holders.
     * @param modulePairs Compliance modules and their parameters.
     * @param tokenIssuer_ The wallet address of the issuer for this specific token creation.
     * @return The address of the newly created token contract.
     */
    function createToken(
        MySMARTTokenFactory tokenFactory, // Pass the specific factory instance
        string memory name,
        string memory symbol,
        uint256[] memory claimTopics,
        ISMART.ComplianceModuleParamPair[] memory modulePairs,
        address tokenIssuer_ // Allow overriding the default issuer per-token
    )
        public
        returns (
            address // Returns the token contract address
        )
    {
        // 1. Create the token contract
        vm.startPrank(tokenIssuer_);
        address tokenAddress = tokenFactory.create(name, symbol, 18, claimTopics, modulePairs);
        vm.stopPrank();

        // 2. Create the token's on-chain identity
        vm.startPrank(_platformAdmin); // Platform admin creates the token identity
        // Use the specific token issuer's wallet address for identity creation
        address tokenIdentityAddress = _identityFactory.createTokenIdentity(tokenAddress, tokenIssuer_);
        vm.stopPrank();

        // 3. Set the on-chain ID on the token contract
        vm.startPrank(tokenIssuer_); // Specific token issuer sets the on-chain ID
        MySMARTToken(tokenAddress).setOnchainID(tokenIdentityAddress);
        vm.stopPrank();

        return tokenAddress;
    }

    /**
     * @notice Mints tokens.
     * @param tokenAddress The address of the token contract.
     * @param tokenIssuer_ The wallet address of the issuer performing the mint.
     * @param to The recipient's wallet address.
     * @param amount The amount to mint.
     */
    function mintToken(address tokenAddress, address tokenIssuer_, address to, uint256 amount) public {
        // Use the specified token issuer's wallet address to mint
        vm.startPrank(tokenIssuer_);
        MySMARTToken(tokenAddress).mint(to, amount);
        vm.stopPrank();
    }

    /**
     * @notice Gets the token balance of a wallet.
     * @param tokenAddress The address of the token contract.
     * @param walletAddress The address of the wallet to check.
     * @return The token balance.
     */
    function getBalance(address tokenAddress, address walletAddress) public view returns (uint256) {
        return MySMARTToken(tokenAddress).balanceOf(walletAddress);
    }

    /**
     * @notice Transfers tokens between wallets.
     * @param tokenAddress The address of the token contract.
     * @param from The sender's wallet address.
     * @param to The recipient's wallet address.
     * @param amount The amount to transfer.
     */
    function transferToken(address tokenAddress, address from, address to, uint256 amount) public {
        vm.startPrank(from);
        MySMARTToken(tokenAddress).transfer(to, amount);
        vm.stopPrank();
    }

    function pauseToken(address tokenAddress, address tokenIssuer_) public {
        vm.startPrank(tokenIssuer_);
        MySMARTToken(tokenAddress).pause();
        vm.stopPrank();
    }
}
