// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMARTComplianceModule } from "../interface/ISMARTComplianceModule.sol";
import { ISMART } from "../interface/ISMART.sol";
import { ISMARTIdentityRegistry } from "../interface/ISMARTIdentityRegistry.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title AbstractComplianceModule
 * @notice Base abstract contract for  compliance modules
 */
abstract contract AbstractComplianceModule is ISMARTComplianceModule, ERC165 {
    /**
     * @inheritdoc ISMARTComplianceModule
     */
    function transferred(
        address _token,
        address _from,
        address _to,
        uint256 _value,
        bytes calldata _params
    )
        external
        override
    { }

    /**
     * @inheritdoc ISMARTComplianceModule
     */
    function destroyed(address _token, address _from, uint256 _value, bytes calldata _params) external override { }

    /**
     * @inheritdoc ISMARTComplianceModule
     */
    function created(address _token, address _to, uint256 _value, bytes calldata _params) external override { }

    /**
     * @inheritdoc ERC165
     * @dev Indicates support for the ISMARTComplianceModule interface.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(ISMARTComplianceModule).interfaceId || super.supportsInterface(interfaceId);
    }
}
