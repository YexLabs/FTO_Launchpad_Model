// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

interface IYexFTOHook {
    function setFTOPair(address pair_) external;
    
    function beforeAddLiquidity(address, uint256) external returns (bytes4);
    function afterAddLiquidity(address, uint256) external returns (uint256 remainTokenProviderLpAmount, uint256 remainUsersLpAmount);
    
    function claimProjectLP(uint256 lpAmount) external;
}