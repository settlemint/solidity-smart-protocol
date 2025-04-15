// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { MySMARTToken } from "./MySMARTToken.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title MySMARTTokenFactory
/// @notice Factory contract for deploying MySMARTToken instances
contract MySMARTTokenFactory is ReentrancyGuard {
    /// @notice Custom errors for the MySMARTTokenFactory contract
    error AddressAlreadyDeployed();
    error InvalidOnchainID();
    error InvalidIdentityRegistry();
    error InvalidCompliance();

    /// @notice The address of the IdentityRegistry contract
    address public immutable identityRegistry;

    /// @notice The address of the Compliance contract
    address public immutable compliance;

    /// @notice Mapping to track if an address was deployed by this factory
    mapping(address => bool) public isFactoryToken;

    /// @notice Emitted when a new SMART token is created
    /// @param token The address of the newly created token
    /// @param creator The address that created the token
    event SMARTTokenCreated(address indexed token, address indexed creator);

    /// @notice Deploys a new MySMARTTokenFactory contract
    /// @param identityRegistry_ The address of the IdentityRegistry contract
    /// @param compliance_ The address of the Compliance contract
    constructor(address identityRegistry_, address compliance_) {
        if (identityRegistry_ == address(0)) revert InvalidIdentityRegistry();
        if (compliance_ == address(0)) revert InvalidCompliance();

        identityRegistry = identityRegistry_;
        compliance = compliance_;
    }

    /// @notice Creates a new SMART token with the specified parameters
    /// @dev Uses CREATE2 for deterministic addresses and includes reentrancy protection
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param decimals The number of decimals for the token
    /// @param onchainID The address of the OnchainID contract
    /// @param requiredClaimTopics The array of required claim topics
    /// @param initialModules The array of initial module addresses
    /// @return token The address of the newly created token
    function create(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address onchainID,
        uint256[] memory requiredClaimTopics,
        address[] memory initialModules
    )
        external
        nonReentrant
        returns (address token)
    {
        // Validate input parameters
        if (onchainID == address(0)) revert InvalidOnchainID();

        // Check if address is already deployed
        address predicted =
            predictAddress(msg.sender, name, symbol, decimals, onchainID, requiredClaimTopics, initialModules);
        if (isAddressDeployed(predicted)) revert AddressAlreadyDeployed();

        bytes32 salt = _calculateSalt(name, symbol, decimals, identityRegistry, compliance);

        MySMARTToken newToken = new MySMARTToken{ salt: salt }(
            name, symbol, decimals, onchainID, identityRegistry, compliance, requiredClaimTopics, initialModules
        );

        token = address(newToken);
        isFactoryToken[token] = true;

        emit SMARTTokenCreated(token, msg.sender);
    }

    /// @notice Predicts the address where a token would be deployed
    /// @param sender The address that would create the token
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param decimals The number of decimals for the token
    /// @param onchainID The address of the OnchainID contract
    /// @param requiredClaimTopics The array of required claim topics
    /// @param initialModules The array of initial module addresses
    /// @return predicted The address where the token would be deployed
    function predictAddress(
        address sender,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address onchainID,
        uint256[] memory requiredClaimTopics,
        address[] memory initialModules
    )
        public
        view
        returns (address predicted)
    {
        bytes32 salt = _calculateSalt(name, symbol, decimals, identityRegistry, compliance);

        predicted = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            keccak256(
                                abi.encodePacked(
                                    type(MySMARTToken).creationCode,
                                    abi.encode(
                                        name,
                                        symbol,
                                        decimals,
                                        onchainID,
                                        identityRegistry,
                                        compliance,
                                        requiredClaimTopics,
                                        initialModules
                                    )
                                )
                            )
                        )
                    )
                )
            )
        );
    }

    /// @notice Calculates the salt for CREATE2 deployment
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param decimals The number of decimals for the token
    /// @param registry The address of the IdentityRegistry contract
    /// @param compliance_ The address of the Compliance contract
    /// @return The calculated salt for CREATE2 deployment
    function _calculateSalt(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address registry,
        address compliance_
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(name, symbol, decimals, registry, compliance_));
    }

    /// @notice Checks if an address was deployed by this factory
    /// @param token The address to check
    /// @return True if the address was created by this factory, false otherwise
    function isAddressDeployed(address token) public view returns (bool) {
        return isFactoryToken[token];
    }
}
