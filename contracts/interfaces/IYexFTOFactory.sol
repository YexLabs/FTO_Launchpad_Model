// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

interface IYexFTOFactory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    event RaisedTokenAdded(address indexed token);

    event RaisedTokenRemoved(address indexed token);

    function getPair(
        address raisedToken,
        address launchedToken
    ) external view returns (address);

    function allPairs(uint) external view returns (address);

    function raisedTokens(uint) external view returns (address);

    function allPairsLength() external view returns (uint);

    function allRaisedTokens() external view returns (address[] memory);

    function isRaisedToken(address) external view returns (bool);

    function pause(address raisedToken, address launchedToken) external;

    function resume(address raisedToken, address launchedToken) external;

    function createFTO(
        address provider,
        address raisedToken,
        string calldata name,
        string calldata symbol,
        uint256 amount,
        address poolHandler,
        uint256 rasingCycle
    ) external returns (address pair);

    function addEvent(address depositer, address ftoPair) external;

    function events(
        address depositer
    ) external view returns (address[] memory pairs);

    function withdrawFee(
        address raisedToken,
        address launchedToken,
        address feeTo
    ) external;
}
