//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Moai {
    IERC20 public immutable USDC;

    constructor(address _usdc)
    {
        USDC = IERC20(_usdc);
    }

    function joinMoai() external {}

    function exitMoai() external{}

    function contribute() external nonReentrant {}

    function distribute() external nonReentrant {}

    function withdraw()
}