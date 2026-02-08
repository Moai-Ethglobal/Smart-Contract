// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Moai} from "./Moai.sol";

/**
 * @title MoaiFactory
 * @notice Factory contract for creating individual Moai savings pools
 */
contract MoaiFactory {
    
    // ============ CUSTOM ERRORS ============
    
    error InvalidParameters();
    
    // ============ STATE VARIABLES ============
    
    address public immutable USDC;
    
    address[] public allMoais;
    mapping(address => address[]) public moaisByCreator;
    
    // ============ EVENTS ============
    
    event MoaiCreated(
        address indexed moaiAddress,
        address indexed creator,
        string name,
        uint256 contributionAmount
    );
    
    // ============ CONSTRUCTOR ============
    
    constructor(address _usdc) {
        if (_usdc == address(0)) revert InvalidParameters();
        USDC = _usdc;
    }
    
    // ============ MOAI CREATION ============
    
    /**
     * @notice Create a new Moai pool
     * @param _name Name of the moai group
     * @param _contributionAmount Monthly contribution amount in USDC (6 decimals)
     * @param _contributionDueDate Day of month (1-28)
     * @param _removalThresholdMonths Months of missed payments before removal vote
     * @param _initialMember Initial member addresses
     * @return moaiAddress Address of the newly created Moai
     */
    function createMoai(
        string memory _name,
        uint256 _contributionAmount,
        uint256 _contributionDueDate,
        uint256 _removalThresholdMonths,
        address  _initialMember
    ) external returns (address moaiAddress) {
        
        // Deploy new Moai
        Moai moai = new Moai(
            USDC,
            _name,
            _contributionAmount,
            _contributionDueDate,
            _removalThresholdMonths,
            _initialMember
        );
        
        moaiAddress = address(moai);
        
        // Track moai
        allMoais.push(moaiAddress);
        moaisByCreator[msg.sender].push(moaiAddress);
        
        emit MoaiCreated(
            moaiAddress,
            _initialMember,
            _name,
            _contributionAmount
        );
        
        return moaiAddress;
    }
    
    // ============ VIEW FUNCTIONS ============
    
    function getAllMoais() external view returns (address[] memory) {
        return allMoais;
    }
    
    function getMoaisByCreator(address creator) external view returns (address[] memory) {
        return moaisByCreator[creator];
    }
    
    function getTotalMoais() external view returns (uint256) {
        return allMoais.length;
    }
}
