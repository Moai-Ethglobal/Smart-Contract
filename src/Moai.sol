// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Moai
 */
contract Moai is ReentrancyGuard {
    
    // ============ CUSTOM ERRORS ============
    
    error MaxMembersReached();
    error AlreadyMember();
    error NotMember();
    error ContributionAlreadyMade();
    error InvalidAmount();
    error EmergencyAmountTooHigh();
    error AlreadyVoted();
    error AlreadyExecuted();
    error NoApprovedWithdrawal();
    error AlreadyDissolved();
    error BelowRemovalThreshold();
    error TooEarlyToDistribute();
    error InsufficientContributors();
    error AlreadyWithdrawnDissolution();
    error InvalidCycleDay();
    
    // ============ STATE VARIABLES ============
    
    IERC20 public immutable USDC;
    
    string public name;
    uint256 public contributionAmount;
    uint256 public cycleDayDue; // Day within 30-day cycle (1-30)
    uint256 public removalThresholdMonths;
    
    uint256 public constant MAX_MEMBERS = 10;
    uint256 public constant GRACE_PERIOD = 1 days; // 1 day after due date
    
    uint256 public currentMonth;
    uint256 public roundRobinIndex;
    uint256 public createdAt;
    uint256 public activeMemberCount;
    
    bool public isDissolved;
    uint256 public dissolutionVotes;
    uint256 public dissolutionSharePerMember;
    
    // Pool balances
    uint256 public emergencyReserve;
    uint256 public monthlyCollectedAmount;
    
    // Emergency settings
    uint256 public constant EMERGENCY_MAX_PERCENT = 15;
    uint256 public constant EMERGENCY_APPROVAL_THRESHOLD = 51;
    
    // Distribution ratio
    uint256 public constant DISTRIBUTION_PERCENT = 70;
    uint256 public constant EMERGENCY_PERCENT = 30;
    
    // ============ OPTIMIZED DATA STRUCTURES ============
    
    struct MemberInfo {
        bool isActive;
        uint256 arrayIndex;        // Position in memberAddresses array
        uint256 joinMonth;         // Month they joined
        uint256 totalContributed;
        uint256 approvedEmergency; // Approved emergency amount
        bool votedDissolution;
        bool withdrawnDissolution;
    }
    
    mapping(address => MemberInfo) public memberInfo;
    address[] public memberAddresses;
    
    // Track last paid month instead of resetting bool
    mapping(address => uint256) public lastPaidMonth;
    
    // NEW: Track pending round-robin distributions
    mapping(address => uint256) public pendingDistribution;
    
    // Emergency requests
    struct EmergencyRequest {
        address beneficiary;
        uint256 amount;
        uint256 approvalCount;
        bool executed;
        mapping(address => bool) hasVoted;
    }
    
    mapping(uint256 => EmergencyRequest) public emergencyRequests;
    uint256 public emergencyRequestCount;
    
    // Member removal requests
    struct RemovalRequest {
        address member;
        uint256 approvalCount;
        bool executed;
        mapping(address => bool) hasVoted;
    }
    
    mapping(uint256 => RemovalRequest) public removalRequests;
    uint256 public removalRequestCount;
    
    // ============ EVENTS ============
    
    event MemberAdded(address indexed member, uint256 joinMonth);
    event MemberRemoved(address indexed member);
    event ContributionMade(address indexed member, uint256 amount, uint256 month);
    event OutstandingPaid(address indexed member, uint256 amount);
    event MonthDistributed(uint256 month, address indexed recipient, uint256 toEmergency, uint256 toDistribution);
    event EmergencyRequested(uint256 indexed requestId, address indexed beneficiary, uint256 amount);
    event EmergencyApproved(uint256 indexed requestId, address indexed beneficiary, uint256 amount);
    event Withdrawn(address indexed recipient, uint256 amount, string reason);
    event MoaiDissolved(uint256 totalAmount, uint256 memberCount, uint256 sharePerMember);
    
    // ============ CONSTRUCTOR ============
    
    /**
     * @notice Initialize a new Moai savings pool
     * @dev Operates on fixed 30-day cycles, NOT calendar months
     * @param _usdc USDC token address
     * @param _name Name of the Moai group
     * @param _contributionAmount Monthly contribution in USDC (6 decimals)
     * @param _cycleDayDue Day within 30-day cycle for contributions (1-30)
     * @param _removalThresholdMonths Months of missed payments before removal eligible
     * @param _initialMember First member address
     */
    constructor(
        address _usdc,
        string memory _name,
        uint256 _contributionAmount,
        uint256 _cycleDayDue,
        uint256 _removalThresholdMonths,
        address _initialMember
    ) {
        if (_contributionAmount == 0) revert InvalidAmount();
        if (_cycleDayDue < 1 || _cycleDayDue > 30) revert InvalidCycleDay();
        if (_initialMember == address(0)) revert InvalidAmount();

        USDC = IERC20(_usdc);
        
        name = _name;
        contributionAmount = _contributionAmount;
        cycleDayDue = _cycleDayDue;
        removalThresholdMonths = _removalThresholdMonths;
        createdAt = block.timestamp;
        currentMonth = 1;
        
        _addMember(_initialMember);
    }
    
    // ============ MEMBER MANAGEMENT ============
    
    function joinMoai() external {
        if (activeMemberCount >= MAX_MEMBERS) revert MaxMembersReached();
        if (memberInfo[msg.sender].isActive) revert AlreadyMember();
        
        _addMember(msg.sender);
    }
    
    function _addMember(address member) internal {
        memberAddresses.push(member);
        
        memberInfo[member] = MemberInfo({
            isActive: true,
            arrayIndex: memberAddresses.length - 1,
            joinMonth: currentMonth,
            totalContributed: 0,
            approvedEmergency: 0,
            votedDissolution: false,
            withdrawnDissolution: false
        });
        
        activeMemberCount++;
        
        emit MemberAdded(member, currentMonth);
    }
    
    function exitMoai() external {
        if (!memberInfo[msg.sender].isActive) revert NotMember();
        
        _removeMember(msg.sender);
    }
    
    function _removeMember(address member) internal {
        // Swap and pop
        uint256 index = memberInfo[member].arrayIndex;
        address lastMember = memberAddresses[memberAddresses.length - 1];
        
        memberAddresses[index] = lastMember;
        memberInfo[lastMember].arrayIndex = index;
        memberAddresses.pop();
        
        memberInfo[member].isActive = false;
        activeMemberCount--;
        
        // Adjust round-robin if needed
        if (roundRobinIndex >= memberAddresses.length && memberAddresses.length > 0) {
            roundRobinIndex = 0;
        }
        
        emit MemberRemoved(member);
    }
    
    // ============ CONTRIBUTION LOGIC ============
    
    function contribute() external nonReentrant {
        if (!memberInfo[msg.sender].isActive) revert NotMember();
        if (lastPaidMonth[msg.sender] == currentMonth) revert ContributionAlreadyMade();
        
        // Transfer USDC from member
        USDC.transferFrom(msg.sender, address(this), contributionAmount);
        
        // Update state
        lastPaidMonth[msg.sender] = currentMonth;
        memberInfo[msg.sender].totalContributed += contributionAmount;
        monthlyCollectedAmount += contributionAmount;
        
        emit ContributionMade(msg.sender, contributionAmount, currentMonth);
    }
    
    /**
     * @notice Pay outstanding back-payments
     * @dev Back-payments go directly to emergency reserve (not distributed to round-robin)
     * @param amount Amount to pay toward outstanding balance
     */
    function payOutstanding(uint256 amount) external nonReentrant {
        if (!memberInfo[msg.sender].isActive) revert NotMember();
        if (amount == 0) revert InvalidAmount();
        
        uint256 outstanding = getOutstanding(msg.sender);
        if (amount > outstanding) revert InvalidAmount();
        
        USDC.transferFrom(msg.sender, address(this), amount);
        memberInfo[msg.sender].totalContributed += amount;
        
        // Back-payments go to emergency reserve (penalty for missing months)
        emergencyReserve += amount;
        
        emit OutstandingPaid(msg.sender, amount);
    }
    
    // ============ DISTRIBUTION LOGIC ============
    
    /**
     * @notice Distribute monthly funds: 70% to round-robin recipient, 30% to emergency reserve
     * @dev Can only be called after distribution date (due date + 1 day) AND 51% paid
     * @dev Operates on fixed 30-day cycles, NOT calendar months
     */
    function distributeMonth() external nonReentrant {
        // Check timing: must be after due date + grace period
        if (block.timestamp < getNextDistributionDate()) revert TooEarlyToDistribute();
        
        // Check minimum contributors (51% must have paid)
        uint256 contributorCount = _countContributors();
        uint256 requiredContributors = (activeMemberCount * 51 + 99) / 100; // Ceiling
        if (contributorCount < requiredContributors) revert InsufficientContributors();
        
        if (monthlyCollectedAmount == 0) revert InvalidAmount();
        
        // Ensure round-robin index is valid (in case members were removed)
        if (roundRobinIndex >= memberAddresses.length) {
            roundRobinIndex = 0;
        }
        
        // Split collected amount: 70% distribution, 30% emergency
        uint256 toEmergency = (monthlyCollectedAmount * EMERGENCY_PERCENT) / 100;
        uint256 toDistribution = monthlyCollectedAmount - toEmergency;
        
        emergencyReserve += toEmergency;
        
        // Allocate distribution to current round-robin recipient
        address recipient = memberAddresses[roundRobinIndex];
        pendingDistribution[recipient] += toDistribution;
        
        emit MonthDistributed(currentMonth, recipient, toEmergency, toDistribution);
        
        // Advance round-robin for next month
        roundRobinIndex = (roundRobinIndex + 1) % memberAddresses.length;
        
        // Reset for next month
        monthlyCollectedAmount = 0;
        currentMonth++;
    }
    
    /**
     * @notice Get next distribution date (due date + 1 day grace period)
     * @dev Based on fixed 30-day cycles from creation time
     */
    function getNextDistributionDate() public view returns (uint256) {
        // Calculate timestamp for (due date + 1 day) of current month
        uint256 monthsSinceCreation = currentMonth - 1;
        uint256 secondsSinceCreation = monthsSinceCreation * 30 days;
        
        // Due date + 1 day grace
        uint256 daysUntilDistribution = cycleDayDue + 1;
        
        return createdAt + secondsSinceCreation + (daysUntilDistribution * 1 days);
    }
    
    /**
     * @notice Count how many members contributed this month
     */
    function _countContributors() internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < memberAddresses.length; i++) {
            if (lastPaidMonth[memberAddresses[i]] == currentMonth) {
                count++;
            }
        }
        return count;
    }
    
    // ============ WITHDRAWAL LOGIC ============
    
    /**
     * @notice Withdraw approved funds
     * @dev Three cases: pending distribution, emergency, dissolution
     */
    function withdraw() external nonReentrant {
        uint256 amount = 0;
        string memory reason;
        
        // Case 1: Pending round-robin distribution
        if (pendingDistribution[msg.sender] > 0) {
            amount = pendingDistribution[msg.sender];
            pendingDistribution[msg.sender] = 0;
            reason = "Round-robin distribution";
        }
        
        // Case 2: Approved emergency
        if (amount == 0 && memberInfo[msg.sender].approvedEmergency > 0) {
            amount = memberInfo[msg.sender].approvedEmergency;
            if (emergencyReserve < amount) revert InvalidAmount();
            
            emergencyReserve -= amount;
            memberInfo[msg.sender].approvedEmergency = 0;
            reason = "Emergency approved";
        }
        
        // Case 3: Dissolution
        if (amount == 0 && isDissolved) {
            if (memberInfo[msg.sender].withdrawnDissolution) revert AlreadyWithdrawnDissolution();
            
            amount = dissolutionSharePerMember;
            memberInfo[msg.sender].withdrawnDissolution = true;
            reason = "Dissolution equal split";
        }
        
        if (amount == 0) revert NoApprovedWithdrawal();
        
        USDC.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount, reason);
    }
    
    // ============ EMERGENCY REQUEST LOGIC ============
    
    function requestEmergency(uint256 amount) external returns (uint256) {
        if (!memberInfo[msg.sender].isActive) revert NotMember();
        
        uint256 maxAmount = (emergencyReserve * EMERGENCY_MAX_PERCENT) / 100;
        if (amount > maxAmount) revert EmergencyAmountTooHigh();
        
        uint256 requestId = emergencyRequestCount++;
        EmergencyRequest storage request = emergencyRequests[requestId];
        request.beneficiary = msg.sender;
        request.amount = amount;
        
        emit EmergencyRequested(requestId, msg.sender, amount);
        
        return requestId;
    }
    
    function voteEmergency(uint256 requestId, bool approve) external {
        if (!memberInfo[msg.sender].isActive) revert NotMember();
        
        EmergencyRequest storage request = emergencyRequests[requestId];
        if (request.hasVoted[msg.sender]) revert AlreadyVoted();
        if (request.executed) revert AlreadyExecuted();
        
        request.hasVoted[msg.sender] = true;
        
        if (approve) {
            request.approvalCount++;
            
            // Check if threshold reached (51%)
            uint256 requiredVotes = (activeMemberCount * EMERGENCY_APPROVAL_THRESHOLD + 99) / 100;
            
            if (request.approvalCount >= requiredVotes && !request.executed) {
                request.executed = true;
                memberInfo[request.beneficiary].approvedEmergency = request.amount;
                
                emit EmergencyApproved(requestId, request.beneficiary, request.amount);
            }
        }
    }
    
    // ============ REMOVAL LOGIC ============
    
    function proposeRemoval(address member) external returns (uint256) {
        if (!memberInfo[msg.sender].isActive) revert NotMember();
        if (!memberInfo[member].isActive) revert NotMember();
        
        // Check if member exceeds threshold
        uint256 outstanding = getOutstanding(member);
        uint256 threshold = contributionAmount * removalThresholdMonths;
        if (outstanding < threshold) revert BelowRemovalThreshold();
        
        uint256 requestId = removalRequestCount++;
        RemovalRequest storage request = removalRequests[requestId];
        request.member = member;
        
        return requestId;
    }
    
    function voteRemoval(uint256 requestId, bool approve) external {
        if (!memberInfo[msg.sender].isActive) revert NotMember();
        
        RemovalRequest storage request = removalRequests[requestId];
        if (request.hasVoted[msg.sender]) revert AlreadyVoted();
        if (request.executed) revert AlreadyExecuted();
        
        request.hasVoted[msg.sender] = true;
        
        if (approve) {
            request.approvalCount++;
            
            // 51% approval needed
            uint256 requiredVotes = (activeMemberCount * 51 + 99) / 100;
            
            if (request.approvalCount >= requiredVotes && !request.executed) {
                request.executed = true;
                _removeMember(request.member);
            }
        }
    }
    
    // ============ DISSOLUTION LOGIC ============
    
    function voteForDissolution() external {
        if (!memberInfo[msg.sender].isActive) revert NotMember();
        if (isDissolved) revert AlreadyDissolved();
        if (memberInfo[msg.sender].votedDissolution) revert AlreadyVoted();
        
        memberInfo[msg.sender].votedDissolution = true;
        dissolutionVotes++;
        
        // Unanimous required (100%)
        if (dissolutionVotes == activeMemberCount) {
            isDissolved = true;
            
            uint256 totalBalance = USDC.balanceOf(address(this));
            dissolutionSharePerMember = totalBalance / activeMemberCount;
            
            // Clear all pending distributions (folded into dissolution share)
            for (uint256 i = 0; i < memberAddresses.length; i++) {
                pendingDistribution[memberAddresses[i]] = 0;
            }
            
            emit MoaiDissolved(totalBalance, activeMemberCount, dissolutionSharePerMember);
        }
    }
    
    // ============ VIEW FUNCTIONS ============
    
    function getMemberCount() external view returns (uint256) {
        return activeMemberCount;
    }
    
    function getEmergencyReserve() external view returns (uint256) {
        return emergencyReserve;
    }
    
    function getAvailableDistribution() external view returns (uint256) {
        uint256 balance = USDC.balanceOf(address(this));
        if (balance > emergencyReserve) {
            return balance - emergencyReserve;
        }
        return 0;
    }
    
    function getTotalBalance() external view returns (uint256) {
        return USDC.balanceOf(address(this));
    }
    
    function getCurrentRecipient() external view returns (address) {
        if (memberAddresses.length == 0) return address(0);
        return memberAddresses[roundRobinIndex];
    }
    
    /**
     * @notice Calculate outstanding amount for a member
     * @dev On-demand calculation - no storage loop needed!
     */
    function getOutstanding(address member) public view returns (uint256) {
        if (!memberInfo[member].isActive) return 0;
        
        uint256 monthsSinceJoin = currentMonth - memberInfo[member].joinMonth;
        uint256 shouldHavePaid = monthsSinceJoin * contributionAmount;
        uint256 actuallyPaid = memberInfo[member].totalContributed;
        
        if (shouldHavePaid > actuallyPaid) {
            return shouldHavePaid - actuallyPaid;
        }
        return 0;
    }
    
    function canBeRemoved(address member) external view returns (bool) {
        uint256 outstanding = getOutstanding(member);
        uint256 threshold = contributionAmount * removalThresholdMonths;
        return outstanding >= threshold;
    }
    
    function getMembers() external view returns (address[] memory) {
        return memberAddresses;
    }
    
    function hasPaidThisMonth(address member) external view returns (bool) {
        return lastPaidMonth[member] == currentMonth;
    }
    
    function getPendingDistribution(address member) external view returns (uint256) {
        return pendingDistribution[member];
    }
}
