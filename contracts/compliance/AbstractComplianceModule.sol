// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol"; // Context might be implicitly inherited via
    // AccessControl
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

// Interface imports
import { ISMARTComplianceModule } from "../interface/ISMARTComplianceModule.sol";
// Unused imports: ISMART, ISMARTIdentityRegistry

/**
 * @title Abstract Compliance Module Base
 * @notice Provides a foundational abstract contract for SMART compliance modules.
 * @dev Implements `ISMARTComplianceModule` and basic `AccessControl`.
 *      Inheriting contracts should implement specific compliance logic (`canTransfer`),
 *      parameter validation (`validateParameters`), and module naming (`name`).
 *      Provides empty virtual implementations for state-changing hooks (`transferred`, `created`, `destroyed`).
 */
abstract contract AbstractComplianceModule is AccessControl, ISMARTComplianceModule {
    // --- Constructor ---
    /**
     * @dev Grants the deployer the `DEFAULT_ADMIN_ROLE` for managing access control within the module itself.
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    // --- ISMARTComplianceModule State-Changing Hooks (Empty Implementations) ---

    /**
     * @inheritdoc ISMARTComplianceModule
     * @dev Empty virtual implementation. Override in inheriting contracts if needed to react to transfers.
     */
    function transferred(
        address, /* _token */
        address, /* _from */
        address, /* _to */
        uint256, /* _value */
        bytes calldata /* _params */
    )
        external
        virtual
        override
    { /* Default: Do nothing */ }

    /**
     * @inheritdoc ISMARTComplianceModule
     * @dev Empty virtual implementation. Override in inheriting contracts if needed to react to burns/destructions.
     */
    function destroyed(
        address, /* _token */
        address, /* _from */
        uint256, /* _value */
        bytes calldata /* _params */
    )
        external
        virtual
        override
    { /* Default: Do nothing */ }

    /**
     * @inheritdoc ISMARTComplianceModule
     * @dev Empty virtual implementation. Override in inheriting contracts if needed to react to mints/creations.
     */
    function created(
        address, /* _token */
        address, /* _to */
        uint256, /* _value */
        bytes calldata /* _params */
    )
        external
        virtual
        override
    { /* Default: Do nothing */ }

    // --- ERC165 Support ---

    /**
     * @inheritdoc IERC165
     * @dev Indicates support for the `ISMARTComplianceModule` interface.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, IERC165)
        returns (bool)
    {
        return interfaceId == type(ISMARTComplianceModule).interfaceId || super.supportsInterface(interfaceId);
    }

    // --- Abstract Functions (Must be implemented by inheriting contracts) ---

    /**
     * @inheritdoc ISMARTComplianceModule
     * @dev MUST be implemented by inheriting contracts to perform the specific compliance check.
     */
    function canTransfer(
        address _token,
        address _from,
        address _to,
        uint256 _value,
        bytes calldata _params
    )
        external
        view
        virtual
        override;

    /**
     * @inheritdoc ISMARTComplianceModule
     * @dev MUST be implemented by inheriting contracts to validate parameters specific to the module.
     */
    function validateParameters(bytes calldata _params) external view virtual override;

    /**
     * @inheritdoc ISMARTComplianceModule
     * @dev MUST be implemented by inheriting contracts to return the human-readable module name.
     */
    function name() external pure virtual override returns (string memory);
}
