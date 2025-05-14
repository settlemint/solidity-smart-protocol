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
import { SMARTTokenAccessManager } from "../../contracts/extensions/access-managed/manager/SMARTTokenAccessManager.sol";

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

    SMARTTokenAccessManager public accessManager;

    MockedForwarder public forwarder;

    function setUpSMART(address _owner) public virtual {
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

        // Initialize the access manager
        vm.prank(_owner);
        accessManager = new SMARTTokenAccessManager(address(forwarder));
    }

    function _setUpIdentity(address _wallet) internal {
        identityUtils.createClientIdentity(_wallet, TestConstants.COUNTRY_CODE_BE);
        claimUtils.issueInvestorClaim(_wallet, TestConstants.CLAIM_TOPIC_KYC, "Verified KYC by Issuer");
    }

    function _setUpIdentities(address[] memory _wallets) internal {
        uint256 walletsLength = _wallets.length;
        for (uint256 i = 0; i < walletsLength; ++i) {
            _setUpIdentity(_wallets[i]);
        }
    }

    function _createAndSetTokenOnchainID(address _token, address _issuer) internal {
        tokenUtils.createAndSetTokenOnchainID(_token, _issuer);
    }

    function _issueCollateralClaim(address _token, address _issuer, uint256 _amount, uint256 _expiry) internal {
        claimUtils.issueCollateralClaim(_token, _issuer, _amount, _expiry);
    }

    function _createIdentity(address _wallet) internal returns (address) {
        return identityUtils.createIdentity(_wallet);
    }

    function _createClaimUtilsForIssuer(
        address claimIssuer_,
        uint256 claimIssuerPrivateKey_
    )
        internal
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

    function _grantAllRoles(address wallet, address defaultAdmin) internal {
        vm.startPrank(defaultAdmin);
        accessManager.grantRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE, wallet);
        accessManager.grantRole(SMARTRoles.COMPLIANCE_ROLE, wallet);
        accessManager.grantRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE, wallet);
        accessManager.grantRole(SMARTRoles.CUSTODIAN_ROLE, wallet);
        accessManager.grantRole(SMARTRoles.EMERGENCY_ROLE, wallet);
        vm.stopPrank();
    }
}
