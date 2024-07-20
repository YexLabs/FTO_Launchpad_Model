// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../interfaces/IYexFTOPairV2.sol";
import "../interfaces/IHenloDexPair.sol";
import "./../libraries/TransferHelper.sol";
import "./../core/YexFTOLaunchToken.sol";
import "./NormalHook.sol";
import "./Lock.sol";

/// @notice This is a hook contract that provides the functionality to remove LP tokens and burn launched tokens.
abstract contract BurnableHook is NormalHook, Lock {

    struct BurnableHookParam {
        address  receiver;
    }

    /**
     * @dev Addresses used as destinations by TokenProviders when withdrawing
     *  RaisedTokens from the hook contract after burning LaunchedTokens.
     * FTOPair address points to the withdrawal address.
     */
    mapping(address => address) public raisedTokenReceiver;

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
    ) public virtual override lockFunction {
        super.createFTO(
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
     * - Register the withdrawal address for the RaisedToken.
     * - The [onlyWhenLocked] modifier ensures that this function is called only when lock is set to 1.
     *   call [createFTO] function -> call [createFTO] function of the FtoFactory
     *   -> call [initialize] function of FTOPair -> call [execute] function
     *   msg.sender has to be FTOPair.
     * - Decode data to obtain [receiver].
     */
    function execute(
        bytes calldata data
    ) public virtual override onlyWhenLocked {
        BurnableHookParam memory params = abi.decode(data, (BurnableHookParam));
        _setBurnableHookParam(params);
    }

    function _setBurnableHookParam(BurnableHookParam memory params) internal {
        require(params.receiver != address(0), "Receiver is invalid.");
        raisedTokenReceiver[msg.sender] = params.receiver;
    }

    /**
     * @param ftoPair FTOPair contract address
     * @dev This function provides the feature to remove LP & burn LaunchedTokens.
     * It is a permissionless function that can be called by anyone.
     */
    function withdrawRaisedToken(address ftoPair) public virtual override {
        _withdrawRaisedToken(ftoPair);
    }

    function _withdrawRaisedToken(address ftoPair) internal {
        /**
         * Get the amount of LP tokens that the hook contract can claim from given ftoPair.
         * If the claimable token amount is 0, revert immediately.
         */
        uint256 lpAmount = IYexFTOPairV2(ftoPair).claimableLP(address(this));
        require(lpAmount > 0, "claimableLP cannot less than 0");

        /**
         * The LP tokens from the ftoPair are claimed and transferred to address(this).
         */
        IYexFTOPairV2(ftoPair).withdrawRaisedToken();

        IYexFTOPairV2.FtoPairTokenInfo memory fPTInfo = IYexFTOPairV2(ftoPair).getFtoPairTokenInfo();

        /**
         * Remove the liquidity of lpAmount from the AMM pool.
         * After removing liquidity, obtain LaunchedToken and RaisedToken from the AMM pool.
         */
        TransferHelper.safeTransfer(fPTInfo.lpToken, fPTInfo.lpToken, lpAmount);
        (uint amount0, uint amount1) = IHenloDexPair(fPTInfo.lpToken).burn(
            address(this)
        );

        (uint256 raisedAmount, uint256 launchedAmount) = fPTInfo.raisedToken < fPTInfo.launchedToken
            ? (amount0, amount1)
            : (amount1, amount0);
        /**
         * Burn the LaunchedToken
         */
        YexFTOLaunchToken(fPTInfo.launchedToken).burn(launchedAmount);

        /**
         * Withdraw the RaisedToken to the receiver registered by the Token Launcher
         *  at the time of FTOPair initialize.
         */
        TransferHelper.safeTransfer(fPTInfo.raisedToken, raisedTokenReceiver[ftoPair], raisedAmount);
    }

    /// @inheritdoc NormalHook
    function getFlags() public pure virtual override returns (YexFTOHook.Flags memory) {
        return YexFTOHook.Flags({
            execute: true,
            liquidityHookOp: false,
            burnable: true
        });
    }
}
