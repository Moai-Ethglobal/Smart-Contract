//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Moai is ReentrancyGuard {
    IERC20 public immutable USDC;
    uint256 public contributionAmount;
    uint256 public contributionDueDate; // Day of month (1-28)
    uint256 public removalThresholdMonths; // Custom per moai
    address[] public members;
    uint256 public constant MAX_MEMBERS = 10;

    uint256 public currentMonth;
    uint256 public roundRobinIndex;
    uint256 public createdAt;

    bool public isDissolved;
    uint256 public dissolutionVotes;

    uint256 public constant EMERGENCY_MAX_PERCENT = 15;
    uint256 public constant EMERGENCY_APPROVAL_THRESHOLD = 51;
    
    mapping(address => bool) public isMember;
    mapping(address => uint256) public outstandingAmount;
    mapping(address => bool) public paidThisMonth;       mapping(address => bool) public votedForDissolution;

    uint256 public monthlyCollectedAmount; // For current month distribution

    mapping(uint256 => RemovalRequest) public removalRequests;
    uint256 public removalRequestCount;


    constructor(address _usdc,uint256 _contributionAmount,
        uint256 _contributionDueDate,
        uint256 _removalThresholdMonths,address initialmember)
    {
        require(_contributionAmount > 0, "Invalid amount");
        require(_contributionDueDate >= 1 && _contributionDueDate <= 28, "Invalid due date");
         
        USDC = IERC20(_usdc);
         contributionAmount = _contributionAmount;
        contributionDueDate = _contributionDueDate;
        removalThresholdMonths = _removalThresholdMonths;
         createdAt = block.timestamp;
        currentMonth = 1;
    }

    function joinMoai() external {
        if (members.length >= MAX_MEMBERS) revert MaxMembersReached();
        if (isMember[msg.sender]) revert AlreadyMember();
        
        members.push(msg.sender);
        isMember[msg.sender] = true;
        
    }

    function exitMoai() external{
          if (!isMember[msg.sender]) revert NotMember();
        
        _removeMember(msg.sender);
    }
    
    function _removeMember(address member) internal {
        isMember[member] = false;
        
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == member) {
                members[i] = members[members.length - 1];
                members.pop();
                break;
            }
        }
        
        if (roundRobinIndex >= members.length && members.length > 0) {
            roundRobinIndex = 0;
        }
        
        emit MemberRemoved(member);
        
        if (members.length == 1) {
            isDissolved = true;
        }
    }
    // contributions


    function contribute() external nonReentrant {
        if (!isMember[msg.sender]) revert NotMember();
        if (paidThisMonth[msg.sender]) revert ContributionAlreadyMade();
        
        USDC.transferFrom(msg.sender, address(this), contributionAmount);
        paidThisMonth[msg.sender] = true;
        monthlyCollectedAmount += contributionAmount;
        
        emit ContributionMade(msg.sender, contributionAmount, currentMonth);
    }
    
     function payOutstanding(uint256 amount) external nonReentrant {
        if (!isMember[msg.sender]) revert NotMember();
        require(amount > 0 && amount <= outstandingAmount[msg.sender], "Invalid amount");
        
        USDC.transferFrom(msg.sender, address(this), amount);
        outstandingAmount[msg.sender] -= amount;
        monthlyCollectedAmount += amount;
        
        emit OutstandingUpdated(msg.sender, outstandingAmount[msg.sender]);
    }

    // voting - dissolution
    function voteForDissolution() external {
        if (!isMember[msg.sender]) revert NotMember();
        if (isDissolved) revert AlreadyDissolved();
        if (votedForDissolution[msg.sender]) revert AlreadyVoted();
        
        votedForDissolution[msg.sender] = true;
        dissolutionVotes++;
        
        if (dissolutionVotes == members.length) {
            isDissolved = true;
            //have to balance to distribute to all members equally
            emit MoaiDissolved(totalBalance, members.length);
        }
    }
    function distribute() external nonReentrant{}

    function withdraw() external nonReentrant{}

    //voting - removal


    function proposeRemoval(address member) external returns (uint256) {
        if (!isMember[msg.sender]) revert NotMember();
        if (!isMember[member]) revert NotMember();
        
        // Check if member exceeds threshold
        uint256 threshold = contributionAmount * removalThresholdMonths;
        require(outstandingAmount[member] >= threshold, "Below removal threshold");
        
        uint256 requestId = removalRequestCount++;
        RemovalRequest storage request = removalRequests[requestId];
        request.member = member;
        
        return requestId;
    }
    
    function voteRemoval(uint256 requestId, bool approve) external {
        if (!isMember[msg.sender]) revert NotMember();
        
        RemovalRequest storage request = removalRequests[requestId];
        if (request.hasVoted[msg.sender]) revert AlreadyVoted();
        if (request.executed) revert("Already executed");
        
        request.hasVoted[msg.sender] = true;
        
        if (approve) {
            request.approvalCount++;
            
            // 51% approval needed
            uint256 requiredVotes = (members.length * 51 + 99) / 100;
            
            if (request.approvalCount >= requiredVotes && !request.executed) {
                request.executed = true;
                _removeMember(request.member);
            }
        }
    }
}