// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { MySMARTTokenFactory } from "../contracts/MySMARTTokenFactory.sol";
import { Identity } from "../contracts/onchainid/Identity.sol";
import { IIdentity } from "../contracts/onchainid/interface/IIdentity.sol";
import { SMARTIdentityRegistryStorage } from "../contracts/SMART/SMARTIdentityRegistryStorage.sol";
import { SMARTTrustedIssuersRegistry } from "../contracts/SMART/SMARTTrustedIssuersRegistry.sol";
import { SMARTIdentityRegistry } from "../contracts/SMART/SMARTIdentityRegistry.sol";
import { SMARTCompliance } from "../contracts/SMART/SMARTCompliance.sol";
import { SMARTIdentityFactory } from "../contracts/SMART/SMARTIdentityFactory.sol";
import { IClaimIssuer } from "../contracts/onchainid/interface/IClaimIssuer.sol";
import { console } from "forge-std/console.sol";

contract SMARTTest is Test {
    address public platformAdmin = makeAddr("Platform Admin");
    address public client1 = makeAddr("Client 1");

    uint256 private issuer1PrivateKey = 0x12345;
    address public issuer1 = vm.addr(issuer1PrivateKey);

    uint256 public constant CLAIM_TOPIC_KYC = 1;
    uint256 public constant CLAIM_TOPIC_AML = 2;
    uint256 public constant ECDSA_TYPE = 1; // Scheme for ECDSA signatures (ERC735)

    SMARTIdentityRegistryStorage identityRegistryStorage;
    SMARTTrustedIssuersRegistry trustedIssuersRegistry;
    SMARTIdentityRegistry identityRegistry;
    SMARTCompliance compliance;
    SMARTIdentityFactory identityFactory;

    MySMARTTokenFactory factory;

    function setUp() public {
        vm.startPrank(platformAdmin);

        identityRegistryStorage = new SMARTIdentityRegistryStorage();
        trustedIssuersRegistry = new SMARTTrustedIssuersRegistry();
        identityRegistry = new SMARTIdentityRegistry(address(identityRegistryStorage), address(trustedIssuersRegistry));
        // This is part of the ERC3643 standard. Not sure if we want to keep this?
        // It is to allow the identity registry to execute functions on the storage contract.
        identityRegistryStorage.bindIdentityRegistry(address(identityRegistry));

        compliance = new SMARTCompliance();
        identityFactory = new SMARTIdentityFactory();

        factory = new MySMARTTokenFactory(address(identityRegistry), address(compliance));

        vm.stopPrank();
    }

    function _createIdentity(address walletAddress_) public returns (address) {
        vm.startPrank(platformAdmin);

        address identity = identityFactory.createIdentity(walletAddress_, new bytes32[](0));

        vm.stopPrank();

        return identity;
    }

    function _createClientIdentity(address clientWalletAddress_, uint16 countryCode_) public returns (address) {
        // Create the identity using the factory
        address identity = _createIdentity(clientWalletAddress_);

        vm.startPrank(platformAdmin);

        // Register the identity in the registry
        identityRegistry.registerIdentity(clientWalletAddress_, IIdentity(identity), countryCode_);

        vm.stopPrank();

        return identity;
    }

    function _createIssuerIdentity(
        address issuerWalletAddress_,
        uint256[] memory claimTopics
    )
        public
        returns (address)
    {
        // Create the identity using the factory
        address issuerIdentityAddr = _createIdentity(issuerWalletAddress_);

        vm.startPrank(platformAdmin);
        // IMPORTANT: Cast the *identity address* to IClaimIssuer for the registry
        trustedIssuersRegistry.addTrustedIssuer(IClaimIssuer(issuerIdentityAddr), claimTopics);

        vm.stopPrank();

        return issuerIdentityAddr; // Return the created identity address
    }

    /**
     * @notice Creates the claim data, hash, and signature for an ERC735 claim.
     * @param issuerPrivateKey_ The private key of the issuer to sign the claim.
     * @param clientIdentityAddr The address of the client's identity contract.
     * @param claimTopic The topic of the claim.
     * @param claimDataString The string data of the claim.
     * @return data The ABI encoded claim data.
     * @return signature The packed ECDSA signature (r, s, v).
     */
    function _createClaimSignature(
        uint256 issuerPrivateKey_,
        address clientIdentityAddr,
        uint256 claimTopic,
        string memory claimDataString
    )
        internal
        pure
        returns (bytes memory data, bytes memory signature)
    {
        data = abi.encode(claimDataString);
        bytes32 dataHash = keccak256(abi.encode(clientIdentityAddr, claimTopic, data));
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPrivateKey_, prefixedHash);
        signature = abi.encodePacked(r, s, v);

        return (data, signature);
    }

    function _verifyClaim(
        IClaimIssuer claimIssuer,
        IIdentity clientIdentity,
        uint256 claimTopic,
        bytes memory signature,
        bytes memory data
    )
        internal
        view
        returns (bool)
    {
        return claimIssuer.isClaimValid(clientIdentity, claimTopic, signature, data);
    }

    function _issueClaim(
        uint256 issuerPrivateKey_,
        address issuerIdentityAddr_, // Changed parameter name for clarity
        address clientWalletAddress_,
        uint256 claimTopic,
        string memory claimData
    )
        public
    {
        // 1. Get client's identity contract
        IIdentity clientIdentity = identityRegistry.identity(clientWalletAddress_);
        address clientIdentityAddr = address(clientIdentity);
        require(clientIdentityAddr != address(0), "Client identity not found");

        // 2. Create signature
        (bytes memory data, bytes memory signature) =
            _createClaimSignature(issuerPrivateKey_, clientIdentityAddr, claimTopic, claimData);

        // 3. Client adds the claim to their identity
        vm.startPrank(clientWalletAddress_);

        bool isValid =
            _verifyClaim(IClaimIssuer(address(issuerIdentityAddr_)), clientIdentity, claimTopic, signature, data);

        require(isValid, "Claim not valid with issuer");

        // Pass the issuer's *identity contract address* as the issuer
        clientIdentity.addClaim(claimTopic, ECDSA_TYPE, issuerIdentityAddr_, signature, data, "");

        vm.stopPrank();
    }

    function test_Mint() public {
        // Create the client identity
        _createClientIdentity(client1, 56);

        // Create the issuer identity
        uint256[] memory claimTopics = new uint256[](2);
        claimTopics[0] = CLAIM_TOPIC_KYC;
        claimTopics[1] = CLAIM_TOPIC_AML;
        // Store the issuer's identity contract address
        address issuer1Identity = _createIssuerIdentity(issuer1, claimTopics);

        // Issue claims from issuer1 to client1
        // Pass the issuer's identity address, not wallet address
        _issueClaim(issuer1PrivateKey, issuer1Identity, client1, CLAIM_TOPIC_KYC, "Verified KYC by Issuer 1");
        _issueClaim(issuer1PrivateKey, issuer1Identity, client1, CLAIM_TOPIC_AML, "Verified AML by Issuer 1");

        // TODO: Add assertions to verify claims exist on client1's identity
    }
}
