// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SMARTIdentityFactory } from "../../contracts/SMART/SMARTIdentityFactory.sol";
import { SMARTCompliance } from "../../contracts/SMART/SMARTCompliance.sol";
import { ISMART } from "../../contracts/SMART/interface/ISMART.sol";
import { SMARTToken } from "../../contracts/SMART/SMARTToken.sol";
import { SMARTTokenUpgradeable } from "../../contracts/SMART/SMARTTokenUpgradeable.sol";
import { SMARTIdentityRegistry } from "../../contracts/SMART/SMARTIdentityRegistry.sol";
import { SMARTPausable } from "../../contracts/SMART/extensions/SMARTPausable.sol";

contract TokenUtils is Test {
    address internal _platformAdmin;
    SMARTIdentityFactory internal _identityFactory;
    SMARTCompliance internal _compliance; // Reference if needed, though factory uses it
    SMARTIdentityRegistry internal _identityRegistry;

    constructor(
        address platformAdmin_,
        SMARTIdentityFactory identityFactory_,
        SMARTIdentityRegistry identityRegistry_,
        SMARTCompliance compliance_ // Pass compliance even if factory uses it, might be needed elsewhere
    ) {
        _platformAdmin = platformAdmin_;
        _identityFactory = identityFactory_;
        _compliance = compliance_;
        _identityRegistry = identityRegistry_;
    }

    /**
     * @notice Creates a new SMART token using a specified factory.
     * @param name The token name.
     * @param symbol The token symbol.
     * @param claimTopics Required claim topics for holders.
     * @param modulePairs Compliance modules and their parameters.
     * @param tokenIssuer_ The wallet address of the issuer for this specific token creation.
     * @return The address of the newly created token contract.
     */
    function createToken(
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
        SMARTToken token = new SMARTToken(
            name,
            symbol,
            18,
            address(0),
            address(_identityRegistry),
            address(_compliance),
            claimTopics,
            modulePairs,
            tokenIssuer_
        );
        address tokenAddress = address(token);
        vm.stopPrank();

        // 2. Create the token's on-chain identity
        _createAndSetTokenOnchainID(tokenAddress, tokenIssuer_);

        return tokenAddress;
    }

    /**
     * @notice Creates a new SMART token using a specified factory.
     * @param name The token name.
     * @param symbol The token symbol.
     * @param claimTopics Required claim topics for holders.
     * @param modulePairs Compliance modules and their parameters.
     * @param tokenIssuer_ The wallet address of the issuer for this specific token creation.
     * @return The address of the newly created token contract.
     */
    function createUpgradeableToken(
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
        // 1. Deploy the implementation contract (no constructor args for upgradeable)
        // Note: Prank is not strictly needed here as constructor is empty, but keeping for consistency
        vm.startPrank(tokenIssuer_);
        SMARTTokenUpgradeable implementation = new SMARTTokenUpgradeable();

        // 2. Encode the initializer call data
        bytes memory initializeData = abi.encodeWithSelector(
            implementation.initialize.selector,
            name,
            symbol,
            18, // Standard decimals
            address(0), // onchainID will be set by _createAndSetTokenOnchainID via proxy
            address(_identityRegistry),
            address(_compliance),
            claimTopics,
            modulePairs,
            tokenIssuer_ // Initial owner
        );

        // 3. Deploy the ERC1967Proxy pointing to the implementation and initializing it
        // The proxy's owner (admin) is implicitly msg.sender here, which is the test contract.
        // This is usually fine for testing, but for mainnet, consider proxy admin ownership.
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initializeData);
        address tokenProxyAddress = address(proxy);
        vm.stopPrank();

        // 4. Create the token's on-chain identity (using platform admin)
        // This interacts with the proxy address now.
        _createAndSetTokenOnchainID(tokenProxyAddress, tokenIssuer_);

        return tokenProxyAddress; // Return the proxy address
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
        ISMART(tokenAddress).mint(to, amount);
        vm.stopPrank();
    }

    /**
     * @notice Gets the token balance of a wallet.
     * @param tokenAddress The address of the token contract.
     * @param walletAddress The address of the wallet to check.
     * @return The token balance.
     */
    function getBalance(address tokenAddress, address walletAddress) public view returns (uint256) {
        return ISMART(tokenAddress).balanceOf(walletAddress);
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
        ISMART(tokenAddress).transfer(to, amount);
        vm.stopPrank();
    }

    function pauseToken(address tokenAddress, address tokenIssuer_) public {
        vm.startPrank(tokenIssuer_);
        SMARTPausable(tokenAddress).pause();
        vm.stopPrank();
    }

    function _createAndSetTokenOnchainID(address tokenAddress, address tokenIssuer_) internal returns (address) {
        // Ensure tokenAddress is the proxy address when dealing with upgradeable tokens
        vm.startPrank(_platformAdmin); // Platform admin creates the token identity
        // Use the specific token issuer's wallet address for identity creation
        address tokenIdentityAddress = _identityFactory.createTokenIdentity(tokenAddress, tokenIssuer_);
        vm.stopPrank();

        // 3. Set the on-chain ID on the token contract (via the proxy)
        vm.startPrank(tokenIssuer_); // Specific token issuer sets the on-chain ID
        ISMART(tokenAddress).setOnchainID(tokenIdentityAddress); // Calling through the proxy
        vm.stopPrank();

        return tokenIdentityAddress;
    }
}
