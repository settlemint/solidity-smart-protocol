// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ERC2771Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ISMARTFixedYieldSchedule } from "./ISMARTFixedYieldSchedule.sol";
import { ISMARTYield } from "./../../ISMARTYield.sol";

/// @title FixedYield - A contract for managing token yield distributions
/// @notice This contract implements a fixed yield schedule for ERC20 tokens, allowing for periodic
/// yield distributions based on token balances. It supports features like historical balance tracking,
/// period-based distributions, and pro-rated yield calculations.
/// @dev Inherits from AccessControl for role-based permissions and ERC2771Context for meta-transaction
/// support. Works with ERC20Yield-compatible tokens to manage yield distributions. Uses timestamps for
/// period calculations and maintains a history of distributions.
/// @custom:security-contact support@settlemint.com
contract SMARTFixedYieldSchedule is
    AccessControl,
    Pausable,
    ERC2771Context,
    ISMARTFixedYieldSchedule,
    ReentrancyGuard
{
    /// @notice Custom errors for the FixedYieldSchedule contract
    /// @dev These errors provide more gas-efficient and descriptive error handling
    error InvalidToken();
    error InvalidStartDate();
    error InvalidEndDate();
    error InvalidRate();
    error InvalidInterval();
    error NoYieldAvailable();
    error ScheduleNotActive();
    error InsufficientUnderlyingBalance();
    error InvalidUnderlyingAsset();
    error InvalidAmount();
    error YieldTransferFailed();
    error InvalidPeriod();

    /// @notice The basis points denominator used for rate calculations (10,000 = 100%)
    /// @dev Used to convert basis points to percentages (e.g., 500 basis points = 5%)
    uint256 public constant RATE_BASIS_POINTS = 10_000;

    /// @notice The token this schedule is for
    /// @dev Must implement the ERC20Yield interface
    ISMARTYield private immutable _token;

    /// @notice The underlying asset used for yield payments
    /// @dev Must be a valid ERC20 token contract
    IERC20 private immutable _underlyingAsset;

    /// @notice The start date of the yield schedule
    /// @dev Must be in the future when the contract is deployed
    uint256 private immutable _startDate;

    /// @notice The end date of the yield schedule
    /// @dev Must be after the start date
    uint256 private immutable _endDate;

    /// @notice The yield rate in basis points
    /// @dev 1 basis point = 0.01%, must be greater than 0
    uint256 private immutable _rate;

    /// @notice The interval between distributions in seconds
    /// @dev Must be greater than 0
    uint256 private immutable _interval;

    /// @notice Array of timestamps when each period ends
    /// @dev Calculated and stored at deployment for gas-efficient period lookups
    uint256[] private _periodEndTimestamps;

    /// @notice Mapping of holder address to last claimed period
    /// @dev Used to track which periods each holder has claimed
    mapping(address holder => uint256 lastClaimedPeriod) private _lastClaimedPeriod;

    /// @notice The total amount of yield claimed across all holders
    /// @dev Used to track total distributions and calculate remaining yield
    uint256 private _totalClaimed;

    /// @notice Event emitted when underlying assets are topped up
    event UnderlyingAssetTopUp(address indexed from, uint256 amount);

    /// @notice Event emitted when underlying assets are withdrawn by admin
    event UnderlyingAssetWithdrawn(address indexed to, uint256 amount);

    /// @notice Event emitted when yield is claimed
    /// @param holder The address claiming the yield
    /// @param totalAmount The total amount of yield claimed
    /// @param fromPeriod The first period being claimed
    /// @param toPeriod The last period being claimed
    /// @param periodAmounts Array of amounts claimed for each period
    /// @param unclaimedYield Total amount of unclaimed yield after this claim
    event YieldClaimed(
        address indexed holder,
        uint256 totalAmount,
        uint256 fromPeriod,
        uint256 toPeriod,
        uint256[] periodAmounts,
        uint256 unclaimedYield
    );

    /// @notice Deploys a new FixedYield contract
    /// @param tokenAddress The address of the token this schedule is for
    /// @param initialOwner The address that will receive admin rights
    /// @param startDate_ The timestamp when the schedule starts
    /// @param endDate_ The timestamp when the schedule ends
    /// @param rate_ The yield rate in basis points (1 basis point = 0.01%, e.g., 500 = 5%)
    /// @param interval_ The interval between distributions in seconds
    constructor(
        address tokenAddress,
        address initialOwner,
        uint256 startDate_,
        uint256 endDate_,
        uint256 rate_,
        uint256 interval_,
        address forwarder
    )
        ERC2771Context(forwarder)
    {
        if (tokenAddress == address(0)) revert InvalidToken();
        if (startDate_ <= block.timestamp) revert InvalidStartDate();
        if (endDate_ <= startDate_) revert InvalidEndDate();
        if (rate_ == 0) revert InvalidRate();
        if (interval_ == 0) revert InvalidInterval();

        _token = ISMARTYield(tokenAddress);
        _underlyingAsset = _token.yieldToken();
        if (address(_underlyingAsset) == address(0)) revert InvalidUnderlyingAsset();

        _startDate = startDate_;
        _endDate = endDate_;
        _rate = rate_;
        _interval = interval_;

        // Calculate and cache period end timestamps
        uint256 totalPeriods = ((endDate_ - startDate_) / interval_) + 1;
        for (uint256 i = 0; i < totalPeriods; ++i) {
            uint256 timestamp = startDate_ + ((i + 1) * interval_);
            // If this period would end after schedule end date, cap it
            if (timestamp > endDate_) {
                timestamp = endDate_;
            }
            _periodEndTimestamps.push(timestamp);
        }

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
    }

    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return super._msgSender();
    }

    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return super._msgData();
    }

    function _contextSuffixLength() internal view override(Context, ERC2771Context) returns (uint256) {
        return super._contextSuffixLength();
    }

    /// @notice Returns all period end timestamps for this yield schedule
    /// @return Array of timestamps when each period ends
    function allPeriods() public view returns (uint256[] memory) {
        return _periodEndTimestamps;
    }

    /// @notice Returns the period end timestamp for a specific period
    /// @param period The period number (1-based)
    /// @return The timestamp when the period ends
    function periodEnd(uint256 period) public view returns (uint256) {
        if (period == 0 || period > _periodEndTimestamps.length) revert InvalidPeriod();
        return _periodEndTimestamps[period - 1];
    }

    /// @notice Returns the current ongoing period number
    /// @return The current period number (0 if schedule hasn't started)
    function currentPeriod() public view returns (uint256) {
        if (block.timestamp < _startDate) return 0;
        if (block.timestamp >= _endDate) return _periodEndTimestamps.length;
        return ((block.timestamp - _startDate) / _interval) + 1;
    }

    /// @notice Returns the last completed period number that can be claimed
    /// @return The last completed period number (0 if no periods completed)
    function lastCompletedPeriod() public view returns (uint256) {
        if (block.timestamp <= _startDate) return 0;

        // If we're past the end date, return the total number of periods
        if (block.timestamp >= _endDate) {
            return _periodEndTimestamps.length;
        }

        // Calculate how many complete intervals have passed
        uint256 elapsedTime = block.timestamp - _startDate;
        uint256 completeIntervals = elapsedTime / _interval;

        // Cap at total number of periods
        return completeIntervals < _periodEndTimestamps.length ? completeIntervals : _periodEndTimestamps.length;
    }

    /// @notice Returns time until next period starts in seconds
    /// @return Time remaining in current period
    function timeUntilNextPeriod() public view returns (uint256) {
        if (block.timestamp < _startDate) {
            return _startDate - block.timestamp;
        }

        if (block.timestamp >= _endDate) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - _startDate;
        // slither-disable-next-line weak-prng
        uint256 currentPeriodElapsed = elapsedTime % _interval;
        return _interval - currentPeriodElapsed;
    }

    /// @notice Returns the last claimed period for a holder
    /// @param holder The address to check
    /// @return The last period number claimed by the holder
    function lastClaimedPeriod(address holder) public view returns (uint256) {
        return _lastClaimedPeriod[holder];
    }

    /// @notice Returns the last claimed period for the caller
    /// @return The last period number claimed by the caller
    function lastClaimedPeriod() public view returns (uint256) {
        return lastClaimedPeriod(_msgSender());
    }

    /// @notice Calculates the total unclaimed yield across all holders
    /// @dev This includes all completed periods that haven't been claimed yet. It iterates through
    /// each completed period, using the historical total supply at the end of that period
    /// for accurate calculation. This approach is more gas-intensive than using the current
    /// total supply but provides correct results if total supply changes over time.
    /// @return The total amount of unclaimed yield
    function totalUnclaimedYield() public view returns (uint256) {
        uint256 lastPeriod = lastCompletedPeriod();
        if (lastPeriod < 1) return 0;

        uint256 totalYieldAccrued = 0;
        // Note: Basis per unit might vary per holder, but for total unclaimed,
        // we use the generic basis for address(0). Assume this basis is constant over time.
        uint256 basis = ISMARTYield(_token).yieldBasisPerUnit(address(0));

        // Iterate through each completed period to calculate yield based on historical total supply
        for (uint256 period = 1; period <= lastPeriod; period++) {
            uint256 periodEndTimestamp = _periodEndTimestamps[period - 1];
            // Fetch the total supply as it was at the end of the specific period
            uint256 historicalTotalSupply = ISMARTYield(_token).totalSupplyAt(periodEndTimestamp);
            if (historicalTotalSupply > 0) {
                // Calculate yield for this specific period using its historical supply
                totalYieldAccrued += (historicalTotalSupply * basis * _rate) / RATE_BASIS_POINTS;
            }
        }

        // Subtract amounts already claimed by holders
        // Ensure no underflow if _totalClaimed somehow exceeds calculated accrued yield
        if (totalYieldAccrued <= _totalClaimed) {
            return 0;
        }

        return totalYieldAccrued - _totalClaimed;
    }

    /// @notice Calculates the total yield that will be needed for the next period
    /// @dev This is useful for ensuring sufficient funds are available for the next distribution
    /// @return The total amount of yield needed for the next period
    function totalYieldForNextPeriod() public view returns (uint256) {
        if (block.timestamp >= _endDate) return 0; // No more periods

        // Get total supply and basis for yield calculation
        uint256 totalSupply = IERC20(address(_token)).totalSupply();
        uint256 basis = ISMARTYield(_token).yieldBasisPerUnit(address(0));

        // Calculate yield for one period
        return (totalSupply * basis * _rate) / RATE_BASIS_POINTS;
    }

    /// @notice Calculates the total accrued yield including pro-rated current period
    /// @param holder The address to calculate yield for
    /// @return The total accrued yield amount
    function calculateAccruedYield(address holder) public view returns (uint256) {
        uint256 currentPeriod_ = currentPeriod();
        if (currentPeriod_ < 1) revert ScheduleNotActive();

        uint256 basis = _token.yieldBasisPerUnit(holder);
        uint256 fromPeriod = _lastClaimedPeriod[holder] + 1;
        uint256 lastCompleted = lastCompletedPeriod();

        // Calculate yield for complete unclaimed periods
        uint256 completePeriodAmount = 0;
        for (uint256 period = fromPeriod; period <= lastCompleted; period++) {
            uint256 balance = _token.balanceOfAt(holder, _periodEndTimestamps[period - 1]);
            if (balance > 0) {
                completePeriodAmount += (balance * basis * _rate) / RATE_BASIS_POINTS;
            }
        }

        // Calculate pro-rated yield for current period if we're in one
        uint256 tokenBalance = IERC20(address(_token)).balanceOf(holder);
        uint256 currentPeriodAmount = 0;

        if (tokenBalance > 0) {
            uint256 periodStart = _startDate + ((currentPeriod_ - 1) * _interval);
            uint256 timeInPeriod = block.timestamp - periodStart;
            currentPeriodAmount = (tokenBalance * basis * _rate * timeInPeriod) / (_interval * RATE_BASIS_POINTS);
        }

        return completePeriodAmount + currentPeriodAmount;
    }

    /// @notice Calculates the total accrued yield for the caller including pro-rated current period
    /// @return The total accrued yield amount
    function calculateAccruedYield() public view returns (uint256) {
        return calculateAccruedYield(_msgSender());
    }

    /// @notice Claims all available yield for the caller
    /// @dev Calculates and transfers all unclaimed yield for completed periods
    function claimYield() external nonReentrant whenNotPaused {
        uint256 lastPeriod = lastCompletedPeriod();
        if (lastPeriod < 1) revert NoYieldAvailable();

        uint256 fromPeriod = _lastClaimedPeriod[_msgSender()] + 1;
        if (fromPeriod > lastPeriod) revert NoYieldAvailable();

        uint256 basis = _token.yieldBasisPerUnit(_msgSender());
        uint256 totalAmount = 0;

        // Create array for all periods in range (including zero amounts)
        uint256[] memory periodAmounts = new uint256[](lastPeriod - fromPeriod + 1);

        // Calculate yield for each unclaimed period using historical balances
        for (uint256 period = fromPeriod; period <= lastPeriod; period++) {
            uint256 balance = _token.balanceOfAt(_msgSender(), _periodEndTimestamps[period - 1]);
            if (balance > 0) {
                uint256 periodYield = (balance * basis * _rate) / RATE_BASIS_POINTS;
                totalAmount += periodYield;
                periodAmounts[period - fromPeriod] = periodYield;
            }
            // If balance is 0, the array element remains 0
        }

        if (totalAmount == 0) revert NoYieldAvailable();

        // Update claimed periods before transfer
        _lastClaimedPeriod[_msgSender()] = lastPeriod;
        _totalClaimed += totalAmount;

        // Transfer the yield
        bool success = _underlyingAsset.transfer(_msgSender(), totalAmount);
        if (!success) revert YieldTransferFailed();

        // Calculate remaining unclaimed yield across all holders
        uint256 remainingUnclaimed = totalUnclaimedYield();

        emit YieldClaimed(_msgSender(), totalAmount, fromPeriod, lastPeriod, periodAmounts, remainingUnclaimed);
    }

    /// @notice Allows topping up the contract with underlying assets for yield payments
    /// @param amount The amount of underlying assets to add
    function topUpUnderlyingAsset(uint256 amount) external nonReentrant whenNotPaused {
        bool success = _underlyingAsset.transferFrom(_msgSender(), address(this), amount);
        if (!success) revert InsufficientUnderlyingBalance();

        emit UnderlyingAssetTopUp(_msgSender(), amount);
    }

    /// @notice Withdraws underlying assets
    /// @dev Only callable by admin
    /// @param to The address to send the underlying assets to
    /// @param amount The amount of underlying assets to withdraw
    function withdrawUnderlyingAsset(
        address to,
        uint256 amount
    )
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
    {
        if (to == address(0)) revert InvalidUnderlyingAsset();
        if (amount == 0) revert InvalidAmount();

        uint256 balance = _underlyingAsset.balanceOf(address(this));
        if (amount > balance) revert InsufficientUnderlyingBalance();

        bool success = _underlyingAsset.transfer(to, amount);
        if (!success) revert InsufficientUnderlyingBalance();

        emit UnderlyingAssetWithdrawn(to, amount);
    }

    /// @notice Withdraws all underlying assets
    /// @dev Only callable by admin
    /// @param to The address to send the underlying assets to
    function withdrawAllUnderlyingAsset(address to) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        if (to == address(0)) revert InvalidUnderlyingAsset();

        uint256 balance = _underlyingAsset.balanceOf(address(this));
        if (balance < 1) revert InsufficientUnderlyingBalance();

        bool success = _underlyingAsset.transfer(to, balance);
        if (!success) revert InsufficientUnderlyingBalance();

        emit UnderlyingAssetWithdrawn(to, balance);
    }

    /// @notice Returns the token this schedule is for
    /// @return The ERC20 token address
    function token() external view returns (ISMARTYield) {
        return _token;
    }

    /// @notice Returns the underlying asset used for yield payments
    /// @return The underlying asset token address
    function underlyingAsset() external view returns (IERC20) {
        return _underlyingAsset;
    }

    /// @notice Returns the start date of the yield schedule
    /// @return The timestamp when the schedule starts
    function startDate() external view returns (uint256) {
        return _startDate;
    }

    /// @notice Returns the end date of the yield schedule
    /// @return The timestamp when the schedule ends
    function endDate() external view returns (uint256) {
        return _endDate;
    }

    /// @notice Returns the yield rate
    /// @return The yield rate in basis points (1 basis point = 0.01%)
    function rate() external view returns (uint256) {
        return _rate;
    }

    /// @notice Returns the distribution interval
    /// @return The interval between distributions in seconds
    function interval() external view returns (uint256) {
        return _interval;
    }

    /// @notice Pauses the contract
    /// @dev Only callable by admin
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses the contract
    /// @dev Only callable by admin
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
