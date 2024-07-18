// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "./NormalHook.sol";
import "./VestingHook.sol";
import "./BurnableHook.sol";
contract CustomHook is VestingHook, BurnableHook {
    struct CustomHookParam {
        uint64 startTimestamp;
        uint64 durationSeconds;
        address receiver;
    }

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
    ) public virtual override(VestingHook, BurnableHook) lockFunction {
        NormalHook.createFTO(
            raisedToken,
            name,
            symbol,
            amount,
            launchedTokenPercent,
            poolHandler,
            raisingCycle,
            data
        );
    }

    function execute(
        bytes calldata data
    ) public override(VestingHook, BurnableHook) onlyWhenLocked {
        CustomHookParam memory params = abi.decode(data, (CustomHookParam));

        _setVestingHookParam(VestingHookParam(params.startTimestamp, params.durationSeconds));
        _setBurnableHookParam(BurnableHookParam(params.receiver));
    }

    function liquidityHookOp(
        address lpToken,
        uint256 lpAmount
    ) public override(VestingHook, NormalHook) {
        VestingHook.liquidityHookOp(lpToken, lpAmount);
    }

    function withdrawRaisedToken(
        address ftoPair
    ) public override(BurnableHook, NormalHook) {
        BurnableHook.withdrawRaisedToken(ftoPair);
    }

    function getFlags() public pure override(VestingHook, BurnableHook) returns (YexFTOHook.Flags memory) {
        return YexFTOHook.Flags({
            execute: true,
            liquidityHookOp: true,
            burnable: true
        });
    }
}