// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "./BurnableHook.sol";
import "./NormalHook.sol";
import "./VestingHook.sol";
import "./../libraries/TransferHelper.sol";

contract CustomHook is VestingHook, BurnableHook {
    constructor(address _ftoFactory) NormalHook(_ftoFactory) {
    }

    function createFTO(
        address raisedToken,
        string calldata name,
        string calldata symbol,
        uint256 amount,
        uint256 launchedTokenPercent,
        address poolHandler,
        uint256 raisingCycle,
        bytes calldata data
    ) public override(VestingHook, NormalHook) {
        VestingHook.createFTO(
            raisedToken,
            name,
            symbol,
            amount,
            launchedTokenPercent,
            poolHandler,
            raisingCycle,
            data);
    }

    function afterAddLiquidity(
        address ftoPair,
        address lpToken,
        uint256 lpAmount
    ) public override(VestingHook, NormalHook) {
        VestingHook.afterAddLiquidity(ftoPair, lpToken, lpAmount);
    }

    function execute(
        address ftoPair,
        bytes calldata data
    ) public override(VestingHook, NormalHook) {
        VestingHook.execute(ftoPair, data);
    }

    function claimLP(
        address ftoPair,
        address lpToken
    ) public override(BurnableHook, NormalHook) {
        BurnableHook.claimLP(ftoPair, lpToken);
    }
}