// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { SMARTIdentityRegistry } from "../../../contracts/SMART/SMARTIdentityRegistry.sol";
import { IIdentity } from "../../../contracts/onchainid/interface/IIdentity.sol";
import { IClaimIssuer } from "../../../contracts/onchainid/interface/IClaimIssuer.sol";
import { TestConstants } from "./../Constants.sol"; // Import the constants library

contract ClaimUtils is Test {
    address internal _platformAdmin; // May be needed for setup steps if any
    uint256 internal _claimIssuerPrivateKey;
    SMARTIdentityRegistry internal _identityRegistry;

    // Constants moved here for clarity, or could be kept in Base/Test
    // uint256 public constant CLAIM_TOPIC_KYC = 1; // Removed, now in Base
    // uint256 public constant CLAIM_TOPIC_AML = 2; // Removed, now in Base
    // uint256 public constant ECDSA_TYPE = 1;      // Removed, now in Base

    constructor(address platformAdmin_, uint256 claimIssuerPrivateKey_, SMARTIdentityRegistry identityRegistry_) {
        _platformAdmin = platformAdmin_;
        _claimIssuerPrivateKey = claimIssuerPrivateKey_;
        _identityRegistry = identityRegistry_;
    }

    /**
     * @notice Creates the claim data, hash, and signature for an ERC735 claim.
     * @dev Uses the private key stored in this utility contract.
     * @param clientIdentityAddr The address of the client's identity contract.
     * @param claimTopic The topic of the claim.
     * @param claimDataString The string data of the claim.
     * @return data The ABI encoded claim data.
     * @return signature The packed ECDSA signature (r, s, v).
     */
    function createClaimSignature(
        address clientIdentityAddr,
        uint256 claimTopic,
        string memory claimDataString
    )
        public
        view
        returns (bytes memory data, bytes memory signature)
    {
        data = abi.encode(claimDataString);
        bytes32 dataHash = keccak256(abi.encode(clientIdentityAddr, claimTopic, data));
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));

        // Note: vm.sign requires the private key, which is stored in this contract
        // However, vm is accessed via inheritance, so we need the key passed or stored.
        // Re-reading the design, the key IS stored via constructor.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_claimIssuerPrivateKey, prefixedHash);
        signature = abi.encodePacked(r, s, v);

        return (data, signature);
    }

    /**
     * @notice Verifies a claim signature against a specific issuer identity.
     * @param issuerIdentityAddr_ The identity contract address of the claim issuer.
     * @param clientIdentity The client's identity contract instance.
     * @param claimTopic The topic of the claim.
     * @param signature The signature to verify.
     * @param data The claim data.
     * @return True if the claim is valid according to the issuer, false otherwise.
     */
    function verifyClaim(
        address issuerIdentityAddr_, // Pass the *identity* address of the issuer
        IIdentity clientIdentity,
        uint256 claimTopic,
        bytes memory signature,
        bytes memory data
    )
        public
        view
        returns (bool)
    {
        // Cast the issuer's identity address to IClaimIssuer to call isClaimValid
        return IClaimIssuer(issuerIdentityAddr_).isClaimValid(clientIdentity, claimTopic, signature, data);
    }

    /**
     * @notice Issues a claim from the configured issuer to a client.
     * @param issuerIdentityAddr_ The identity contract address of the claim issuer.
     * @param clientWalletAddress_ The wallet address of the client receiving the claim.
     * @param claimTopic The topic of the claim.
     * @param claimDataString The string data for the claim.
     */
    function issueClaim(
        address issuerIdentityAddr_, // Issuer's identity contract address
        address clientWalletAddress_,
        uint256 claimTopic,
        string memory claimDataString
    )
        public
    {
        // 1. Get client's identity contract
        IIdentity clientIdentity = _identityRegistry.identity(clientWalletAddress_);
        address clientIdentityAddr = address(clientIdentity);
        require(clientIdentityAddr != address(0), "ClaimUtils: Client identity not found");

        // 2. Create signature using the stored private key
        (bytes memory data, bytes memory signature) =
            createClaimSignature(clientIdentityAddr, claimTopic, claimDataString);

        // 3. Verify the claim is valid with the issuer's identity before adding
        bool isValid = verifyClaim(issuerIdentityAddr_, clientIdentity, claimTopic, signature, data);
        require(isValid, "ClaimUtils: Claim not valid with issuer");

        // 4. Client adds the claim to their identity (needs prank)
        vm.startPrank(clientWalletAddress_);
        // Pass the issuer's *identity contract address* as the issuer parameter in addClaim
        // Use ECDSA_TYPE from the constants library
        clientIdentity.addClaim(claimTopic, TestConstants.ECDSA_TYPE, issuerIdentityAddr_, signature, data, "");
        vm.stopPrank();
    }

    /**
     * @notice Issues a standard KYC claim.
     * @param issuerIdentityAddr_ The identity contract address of the claim issuer.
     * @param clientWalletAddress_ The wallet address of the client receiving the claim.
     */
    function issueKYCClaim(address issuerIdentityAddr_, address clientWalletAddress_) public {
        // Use CLAIM_TOPIC_KYC from the constants library
        issueClaim(issuerIdentityAddr_, clientWalletAddress_, TestConstants.CLAIM_TOPIC_KYC, "Verified KYC by Issuer");
    }

    /**
     * @notice Issues a standard AML claim.
     * @param issuerIdentityAddr_ The identity contract address of the claim issuer.
     * @param clientWalletAddress_ The wallet address of the client receiving the claim.
     */
    function issueAMLClaim(address issuerIdentityAddr_, address clientWalletAddress_) public {
        // Use CLAIM_TOPIC_AML from the constants library
        issueClaim(issuerIdentityAddr_, clientWalletAddress_, TestConstants.CLAIM_TOPIC_AML, "Verified AML by Issuer");
    }

    /**
     * @notice Issues both standard KYC and AML claims.
     * @param issuerIdentityAddr_ The identity contract address of the claim issuer.
     * @param clientWalletAddress_ The wallet address of the client receiving the claim.
     */
    function issueAllClaims(address issuerIdentityAddr_, address clientWalletAddress_) public {
        issueKYCClaim(issuerIdentityAddr_, clientWalletAddress_);
        issueAMLClaim(issuerIdentityAddr_, clientWalletAddress_);
    }
}
