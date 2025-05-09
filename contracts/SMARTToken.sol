// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

// Interface imports
import { ISMART } from "./interface/ISMART.sol";
import { ISMARTIdentityRegistry } from "./interface/ISMARTIdentityRegistry.sol";
import { SMARTComplianceModuleParamPair } from "./interface/structs/SMARTComplianceModuleParamPair.sol";

// Core extensions
import { SMART } from "./extensions/core/SMART.sol";
import { SMARTExtension } from "./extensions/common/SMARTExtension.sol";
import { SMARTHooks } from "./extensions/common/SMARTHooks.sol";
import { SMARTAccessControlAuthorization } from "./extensions/core/SMARTAccessControlAuthorization.sol";
import { SMARTExtensionAccessControlAuthorization } from
    "./extensions/common/SMARTExtensionAccessControlAuthorization.sol";

// Feature extensions
import { SMARTPausable } from "./extensions/pausable/SMARTPausable.sol";
import { SMARTPausableAccessControlAuthorization } from
    "./extensions/pausable/SMARTPausableAccessControlAuthorization.sol";
import { SMARTBurnable } from "./extensions/burnable/SMARTBurnable.sol";
import { SMARTBurnableAccessControlAuthorization } from
    "./extensions/burnable/SMARTBurnableAccessControlAuthorization.sol";
import { SMARTCustodian } from "./extensions/custodian/SMARTCustodian.sol";
import { SMARTCustodianAccessControlAuthorization } from
    "./extensions/custodian/SMARTCustodianAccessControlAuthorization.sol";
import { SMARTRedeemable } from "./extensions/redeemable/SMARTRedeemable.sol";
import { SMARTCollateral } from "./extensions/collateral/SMARTCollateral.sol";
/// @title SMARTToken
/// @notice A complete implementation of a SMART token with all available extensions

contract SMARTToken is
    SMART,
    SMARTAccessControlAuthorization,
    SMARTBurnableAccessControlAuthorization,
    SMARTPausableAccessControlAuthorization,
    SMARTCustodianAccessControlAuthorization,
    SMARTCustodian,
    SMARTCollateral,
    SMARTPausable,
    SMARTBurnable,
    SMARTRedeemable,
    AccessControl
{
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_,
        uint256 collateralProofTopic_,
        address initialOwner_
    )
        SMART(
            name_,
            symbol_,
            decimals_,
            onchainID_,
            identityRegistry_,
            compliance_,
            requiredClaimTopics_,
            initialModulePairs_
        )
        SMARTCustodian()
        SMARTCollateral(collateralProofTopic_)
        SMARTPausable()
        SMARTBurnable()
        SMARTRedeemable()
    {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner_);
        _grantRole(BURNER_ROLE, initialOwner_);
        _grantRole(MINTER_ROLE, initialOwner_);
        _grantRole(COMPLIANCE_ADMIN_ROLE, initialOwner_);
        _grantRole(VERIFICATION_ADMIN_ROLE, initialOwner_);
        _grantRole(TOKEN_ADMIN_ROLE, initialOwner_);
        _grantRole(FREEZER_ROLE, initialOwner_);
        _grantRole(FORCED_TRANSFER_ROLE, initialOwner_);
        _grantRole(RECOVERY_ROLE, initialOwner_);
        _grantRole(PAUSER_ROLE, initialOwner_);
    }

    // --- State-Changing Functions (Overrides) ---
    function transfer(address to, uint256 amount) public virtual override(SMART, ERC20, IERC20) returns (bool) {
        return super.transfer(to, amount);
    }

    // --- View Functions (Overrides) ---
    function name() public view virtual override(SMART, ERC20, IERC20Metadata) returns (string memory) {
        return super.name();
    }

    function symbol() public view virtual override(SMART, ERC20, IERC20Metadata) returns (string memory) {
        return super.symbol();
    }

    function decimals() public view virtual override(SMART, ERC20, IERC20Metadata) returns (uint8) {
        return super.decimals();
    }

    function hasRole(
        bytes32 role,
        address account
    )
        public
        view
        virtual
        override(SMARTExtensionAccessControlAuthorization, AccessControl)
        returns (bool)
    {
        return AccessControl.hasRole(role, account);
    }

    /// @dev Overrides ERC165 to ensure that the SMART implementation is used.
    function supportsInterface(bytes4 interfaceId) public view virtual override(SMART, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // --- Hooks ---

    function _beforeMint(
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMART, SMARTCollateral, SMARTCustodian, SMARTHooks)
    {
        super._beforeMint(to, amount);
    }

    function _beforeTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMART, SMARTCustodian, SMARTHooks)
    {
        super._beforeTransfer(from, to, amount);
    }

    function _beforeBurn(address from, uint256 amount) internal virtual override(SMARTCustodian, SMARTHooks) {
        super._beforeBurn(from, amount);
    }

    function _beforeRedeem(
        address owner,
        uint256 amount
    )
        internal
        virtual
        override(SMARTRedeemable, SMARTCustodian, SMARTHooks)
    {
        super._beforeRedeem(owner, amount);
    }

    function _afterMint(address to, uint256 amount) internal virtual override(SMART, SMARTHooks) {
        super._afterMint(to, amount);
    }

    function _afterTransfer(address from, address to, uint256 amount) internal virtual override(SMART, SMARTHooks) {
        super._afterTransfer(from, to, amount);
    }

    function _afterBurn(address from, uint256 amount) internal virtual override(SMART, SMARTHooks) {
        super._afterBurn(from, amount);
    }

    function _afterRedeem(address owner, uint256 amount) internal virtual override(SMARTRedeemable, SMARTHooks) {
        super._afterRedeem(owner, amount);
    }

    // --- Internal Functions (Overrides) ---
    /**
     * @dev Explicitly call the Pausable implementation which includes the `whenNotPaused` check.
     */
    function _update(address from, address to, uint256 value) internal virtual override(SMART, SMARTPausable, ERC20) {
        super._update(from, to, value);
    }

    function _msgSender()
        internal
        view
        virtual
        override(SMARTExtensionAccessControlAuthorization, Context)
        returns (address)
    {
        return Context._msgSender();
    }
}
