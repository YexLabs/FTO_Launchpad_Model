// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "./NormalHook.sol";
import "./VestingHook.sol";
import "./BurnableHook.sol";

/// @notice This is a hook contract that provides vesting and remove/burn functions.
contract CustomHook is VestingHook, BurnableHook {
    struct CustomHookParam {
        uint64 startTimestamp;
        uint64 durationSeconds;
        address receiver;
    }

    constructor(address _ftoFactory) NormalHook(_ftoFactory) {}

    /// @inheritdoc NormalHook
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

    /**
     * @param data bytes data sent from the FTOPair
     * @dev A function called by the FTOPair contract
     * - Save the vesting information in getPair. (for vesting functionality)
     * - Register the withdrawal address for the RaisedToken. (for remove/burn functionality)
     * - The [onlyWhenLocked] modifier ensures that this function is called only when lock is set to 1.
     *   call [createFTO] function -> call [createFTO] function of the FtoFactory
     *   -> call [initialize] function of FTOPair -> call [execute] function
     *   msg.sender has to be FTOPair.
     * - Decode data to obtain [startTimestamp], [durationSeconds] and [receiver].
     */
    function execute(
        bytes calldata data
    ) public override(VestingHook, BurnableHook) onlyWhenLocked {
        CustomHookParam memory params = abi.decode(data, (CustomHookParam));

        _setVestingHookParam(
            VestingHookParam(params.startTimestamp, params.durationSeconds)
        );
        _setBurnableHookParam(BurnableHookParam(params.receiver));
    }

    /// @inheritdoc VestingHook
    function liquidityHookOp(
        address lpToken,
        uint256 lpAmount
    ) public override(VestingHook, NormalHook) {
        VestingHook.liquidityHookOp(lpToken, lpAmount);
    }

    /// @inheritdoc BurnableHook
    function withdrawRaisedToken(
        address ftoPair
    ) public override(BurnableHook, NormalHook) {
        BurnableHook.withdrawRaisedToken(ftoPair);
    }

    /// @inheritdoc NormalHook
    function getFlags()
        public
        pure
        override(VestingHook, BurnableHook)
        returns (YexFTOHook.Flags memory)
    {
        return
            YexFTOHook.Flags({
                execute: true,
                liquidityHookOp: true,
                burnable: true
            });
    }
}
