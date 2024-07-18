// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../interfaces/IYexFTOPair.sol";
import "../interfaces/IHenloDexPair.sol";
import "./../libraries/TransferHelper.sol";
import "./../core/YexFTOLaunchToken.sol";
import "./NormalHook.sol";
import "./Lock.sol";

abstract contract BurnableHook is NormalHook, Lock {

    struct BurnableHookParam {
        address  receiver;
    }

    mapping(address => address) public raisedTokenReceiver;

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

    function withdrawRaisedToken(address ftoPair) public virtual override {
        _withdrawRaisedToken(ftoPair);
    }

    // used for claim and burn, TODO: do we burn lp or burn launchedToken?
    function _withdrawRaisedToken(address ftoPair) internal {
        uint256 lpAmount = IYexFTOPair(ftoPair).claimableLP(address(this));
        require(lpAmount > 0, "claimableLP cannot less than 0");
        IYexFTOPair(ftoPair).withdrawRaisedToken();

        IYexFTOPair.FtoPairTokenInfo memory fPTInfo = IYexFTOPair(ftoPair).getFtoPairTokenInfo();

        // remove liquidity
        TransferHelper.safeTransfer(fPTInfo.lpToken, fPTInfo.lpToken, lpAmount);

        (uint amount0, uint amount1) = IHenloDexPair(fPTInfo.lpToken).burn(
            address(this)
        );

        (uint256 raisedAmount, uint256 launchedAmount) = fPTInfo.raisedToken < fPTInfo.launchedToken
            ? (amount0, amount1)
            : (amount1, amount0);

        YexFTOLaunchToken(fPTInfo.launchedToken).burn(launchedAmount);
        TransferHelper.safeTransfer(fPTInfo.raisedToken, raisedTokenReceiver[ftoPair], raisedAmount);
    }

    function getFlags() public pure virtual override returns (YexFTOHook.Flags memory) {
        return YexFTOHook.Flags({
            execute: true,
            liquidityHookOp: false,
            burnable: true
        });
    }
}
