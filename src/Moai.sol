//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

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


    constructor(address _usdc,uint256 _contributionAmount,
        uint256 _contributionDueDate,
        uint256 _removalThresholdMonths,address initialmember)
    {
        require(_initialMembers.length <= MAX_MEMBERS, "Too many members");
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

    
}