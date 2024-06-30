// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.16;

interface IYexFTOHook {
    function claimLP(address ftoPair, address lpToken) external;

    function execute(address ftoPair, bytes calldata params) external;

    function afterAddLiquidity(
        address ftoPair,
        address lpToken,
        uint256 lpAmount
    ) external;
}
