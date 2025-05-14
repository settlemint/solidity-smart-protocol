// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { InfrastructureUtils } from "../utils/InfrastructureUtils.sol";
import { TestConstants } from "../Constants.sol";
import { TokenUtils } from "../utils/TokenUtils.sol";
import { ClaimUtils } from "../utils/ClaimUtils.sol";
import { IdentityUtils } from "../utils/IdentityUtils.sol";
import { SMARTIdentityRegistry } from "../../contracts/SMARTIdentityRegistry.sol";
import { SMARTCompliance } from "../../contracts/SMARTCompliance.sol";
import { SMARTConstants } from "../../contracts/assets/SMARTConstants.sol";
import { SMARTRoles } from "../../contracts/assets/SMARTRoles.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { MockedForwarder } from "../utils/mocks/MockedForwarder.sol";

abstract contract AbstractSMARTAssetTest is Test {
    address public platformAdmin;
    address public claimIssuer;

    uint256 internal claimIssuerPrivateKey = 0x12345;

    InfrastructureUtils internal infrastructureUtils;
    TokenUtils internal tokenUtils;
    ClaimUtils internal claimUtils;
    IdentityUtils internal identityUtils;

    address public identityRegistry;
    address public compliance;

    MockedForwarder public forwarder;

    function setUp() public {
        // --- Setup platform admin ---
        platformAdmin = makeAddr("Platform Admin");

        // --- Setup claim issuer ---
        claimIssuer = vm.addr(claimIssuerPrivateKey);

        // Set up utils
        infrastructureUtils = new InfrastructureUtils(platformAdmin);
        tokenUtils = new TokenUtils(
            platformAdmin,
            infrastructureUtils.identityFactory(),
            infrastructureUtils.identityRegistry(),
            infrastructureUtils.compliance()
        );
        claimUtils = new ClaimUtils(
            platformAdmin,
            claimIssuer,
            claimIssuerPrivateKey,
            infrastructureUtils.identityRegistry(),
            infrastructureUtils.identityFactory(),
            SMARTConstants.CLAIM_TOPIC_COLLATERAL,
            TestConstants.CLAIM_TOPIC_KYC,
            TestConstants.CLAIM_TOPIC_AML
        );
        identityUtils = new IdentityUtils(
            platformAdmin,
            infrastructureUtils.identityFactory(),
            infrastructureUtils.identityRegistry(),
            infrastructureUtils.trustedIssuersRegistry()
        );

        identityRegistry = address(infrastructureUtils.identityRegistry());
        compliance = address(infrastructureUtils.compliance());

        // Initialize the claim issuer
        uint256[] memory claimTopics = new uint256[](2);
        claimTopics[0] = TestConstants.CLAIM_TOPIC_KYC;
        claimTopics[1] = SMARTConstants.CLAIM_TOPIC_COLLATERAL;
        // Use claimIssuer address directly, createIssuerIdentity handles creating the on-chain identity
        vm.label(claimIssuer, "Claim Issuer");
        address claimIssuerIdentity = identityUtils.createIssuerIdentity(claimIssuer, claimTopics);
        vm.label(claimIssuerIdentity, "Claim Issuer Identity");

        // Initialize the forwarder
        forwarder = new MockedForwarder();
    }

    function setUpIdentity(address _wallet) public {
        identityUtils.createClientIdentity(_wallet, TestConstants.COUNTRY_CODE_BE);
        claimUtils.issueInvestorClaim(_wallet, TestConstants.CLAIM_TOPIC_KYC, "Verified KYC by Issuer");
    }

    function setUpIdentities(address[] memory _wallets) public {
        uint256 walletsLength = _wallets.length;
        for (uint256 i = 0; i < walletsLength; ++i) {
            setUpIdentity(_wallets[i]);
        }
    }

    function createAndSetTokenOnchainID(address _token, address _issuer) public {
        tokenUtils.createAndSetTokenOnchainID(_token, _issuer);
    }

    function issueCollateralClaim(address _token, address _issuer, uint256 _amount, uint256 _expiry) public {
        claimUtils.issueCollateralClaim(_token, _issuer, _amount, _expiry);
    }

    function createIdentity(address _wallet) public returns (address) {
        return identityUtils.createIdentity(_wallet);
    }

    function createClaimUtilsForIssuer(
        address claimIssuer_,
        uint256 claimIssuerPrivateKey_
    )
        public
        returns (ClaimUtils)
    {
        return new ClaimUtils(
            platformAdmin,
            claimIssuer_,
            claimIssuerPrivateKey_,
            infrastructureUtils.identityRegistry(),
            infrastructureUtils.identityFactory(),
            SMARTConstants.CLAIM_TOPIC_COLLATERAL,
            TestConstants.CLAIM_TOPIC_KYC,
            TestConstants.CLAIM_TOPIC_AML
        );
    }

    function grantAllRoles(address contract_, address wallet, address defaultAdmin) public {
        vm.startPrank(defaultAdmin);
        IAccessControl(contract_).grantRole(SMARTRoles.TOKEN_ADMIN_ROLE, wallet);
        IAccessControl(contract_).grantRole(SMARTRoles.COMPLIANCE_ADMIN_ROLE, wallet);
        IAccessControl(contract_).grantRole(SMARTRoles.VERIFICATION_ADMIN_ROLE, wallet);
        IAccessControl(contract_).grantRole(SMARTRoles.MINTER_ROLE, wallet);
        IAccessControl(contract_).grantRole(SMARTRoles.BURNER_ROLE, wallet);
        IAccessControl(contract_).grantRole(SMARTRoles.FREEZER_ROLE, wallet);
        IAccessControl(contract_).grantRole(SMARTRoles.FORCED_TRANSFER_ROLE, wallet);
        IAccessControl(contract_).grantRole(SMARTRoles.RECOVERY_ROLE, wallet);
        IAccessControl(contract_).grantRole(SMARTRoles.PAUSER_ROLE, wallet);
        vm.stopPrank();
    }
}
