//SPDX_License-Identifier: MIT
pragma solidity ^0.8.20;

contract MoaiFactory {
    address public immutable USDC;
    address[] public allMoais;
    mapping(address => address[]) public moaisByCreator;

    constructor(address _usdc)
    {
        USDC = usdc;
    }
    function createMoai(uint256 _contributionAmount, uint256 _contributionDueDate,uint256 _removalThreshold) external returns(address moaiAddress) {
        Moai moai = new Moai(USDC,_contributionAmount,_contributionDueDate,_removalThreshold);
        moaiAddress = address(moai);
        allMoais.push(moaiAddress);
        moaisByCreator[msg.sender].push(moaiAddress);
        return moaiAddress;
    }
}