// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../interfaces/IYexFTOPair.sol";
import "../interfaces/IHenloDexPair.sol";
import "./../libraries/TransferHelper.sol";
import "./../core/YexFTOLaunchToken.sol";
import "./NormalHook.sol";

abstract contract BurnableHook is NormalHook {
    function claimLP(
        address ftoPair,
        address lpToken
    ) public virtual override {
        _claimLPAndBurn(ftoPair, lpToken);
    }

    // used for claim and burn, TODO: do we burn lp or burn launchedToken?
    function _claimLPAndBurn(address ftoPair, address lpToken) internal {
        uint256 lpAmount = IYexFTOPair(ftoPair).claimableLP(address(this));
        require(lpAmount > 0, "claimableLP cannot less than 0");
        IYexFTOPair(ftoPair).claimLP(address(this));

        TransferHelper.safeTransfer(lpToken, lpToken, lpAmount);

        // remove liquidity
        (uint amount0, uint amount1) = IHenloDexPair(lpToken).burn(
            address(this)
        );

        address raisedToken = IYexFTOPair(ftoPair).raisedToken();
        address launchedToken = IYexFTOPair(ftoPair).launchedToken();

        (address token0, ) = raisedToken < launchedToken
            ? (raisedToken, launchedToken)
            : (launchedToken, raisedToken);

        (, uint256 launchedAmount) = raisedToken == token0
            ? (amount0, amount1)
            : (amount1, amount0);

        YexFTOLaunchToken(launchedToken).burn(launchedAmount);
    }
}
