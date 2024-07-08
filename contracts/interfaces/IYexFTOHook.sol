// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.16;

interface IYexFTOHook {
    function createFTO(
        address raisedToken,
        string calldata name,
        string calldata symbol,
        uint256 amount,
        uint256 launchedTokenPercent,
        address poolHandler,
        uint256 rasingCycle,
        bytes calldata data
    ) external;

    function claimLP(address ftoPair, address lpToken) external;

    function execute(bytes calldata params) external;

    function afterAddLiquidity(
        address ftoPair,
        address lpToken,
        uint256 lpAmount
    ) external;
}
