// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

interface IYexFTOFactory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    event BaseTokenAdded(
        address indexed token
    );

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address);

    function allPairs(uint) external view returns (address);
    function baseTokens(uint) external view returns (address);

    function allPairsLength() external view returns (uint);

    function allBaseTokens() external view returns (address[] memory);
    function isBaseToken(address) external view returns (bool);

    function createFTO(
        address tokenA,
        string calldata name,
        string calldata symbol,
        uint256 amount,
        address poolHandler,
        uint256 rasing_cycle
    ) external returns (address pair);

    function addWhiteList(address caller) external;

    function removeWhiteList(address caller) external;

    function addEvent(address depositer, address ftoPair) external;

    function events(
        address depositer
    ) external view returns (address[] memory pairs);
}
