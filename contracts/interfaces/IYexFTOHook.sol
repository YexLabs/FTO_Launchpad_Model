// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.16;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IYexFTOHook is IERC165 {
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

    function withdrawRaisedToken(address ftoPair) external;

    function execute(bytes calldata params) external;

    function liquidityHookOp(address lpToken, uint256 lpAmount) external;
}
