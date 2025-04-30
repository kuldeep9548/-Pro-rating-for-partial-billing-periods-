// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ProRatedBillingSystem
 * @dev Smart contract for managing pro-rated billing periods on Core Chain
 */
contract ProRatedBillingSystem {
    address public owner;
    uint256 public monthlySubscriptionFee;
    uint256 public constant DAYS_IN_MONTH = 30;

    struct Subscription {
        bool isActive;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 lastPaymentTimestamp;
    }

    mapping(address => Subscription) public subscriptions;

    event SubscriptionStarted(address subscriber, uint256 startTime, uint256 endTime, uint256 amountPaid);
    event SubscriptionRenewed(address subscriber, uint256 newEndTime, uint256 amountPaid);
    event ProRatedPaymentProcessed(address subscriber, uint256 daysProRated, uint256 amountPaid);

    constructor(uint256 _monthlyFee) {
        owner = msg.sender;
        monthlySubscriptionFee = _monthlyFee;
    }

    /**
     * @notice Calculate pro-rated fee based on days remaining in billing cycle
     * @param _daysRemaining Number of days remaining in the billing cycle
     * @return The pro-rated fee amount
     */
    function calculateProRatedFee(uint256 _daysRemaining) public view returns (uint256) {
        require(_daysRemaining <= DAYS_IN_MONTH, "Days cannot exceed month length");
        return (monthlySubscriptionFee * _daysRemaining) / DAYS_IN_MONTH;
    }

    /**
     * @notice Start a new subscription with pro-rated billing
     * @param _daysInFirstCycle Days to include in first billing cycle
     */
    function startSubscription(uint256 _daysInFirstCycle) external payable {
        require(!subscriptions[msg.sender].isActive, "Subscription already exists");
        require(_daysInFirstCycle > 0 && _daysInFirstCycle <= DAYS_IN_MONTH, "Invalid days count");
        
        uint256 proRatedFee = calculateProRatedFee(_daysInFirstCycle);
        require(msg.value >= proRatedFee, "Insufficient payment");

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (_daysInFirstCycle * 1 days);
        
        subscriptions[msg.sender] = Subscription({
            isActive: true,
            startTimestamp: startTime,
            endTimestamp: endTime,
            lastPaymentTimestamp: startTime
        });
        
        // Return excess payment if any
        if (msg.value > proRatedFee) {
            payable(msg.sender).transfer(msg.value - proRatedFee);
        }
        
        emit ProRatedPaymentProcessed(msg.sender, _daysInFirstCycle, proRatedFee);
        emit SubscriptionStarted(msg.sender, startTime, endTime, proRatedFee);
    }

    /**
     * @notice Renew an existing subscription for a full month
     */
    function renewSubscription() external payable {
        Subscription storage sub = subscriptions[msg.sender];
        require(sub.isActive, "No active subscription");
        require(msg.value >= monthlySubscriptionFee, "Insufficient payment");
        
        sub.lastPaymentTimestamp = block.timestamp;
        sub.endTimestamp = sub.endTimestamp + (DAYS_IN_MONTH * 1 days);
        
        // Return excess payment if any
        if (msg.value > monthlySubscriptionFee) {
            payable(msg.sender).transfer(msg.value - monthlySubscriptionFee);
        }
        
        emit SubscriptionRenewed(msg.sender, sub.endTimestamp, monthlySubscriptionFee);
    }
}
