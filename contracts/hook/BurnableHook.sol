// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../interfaces/IYexFTOHook.sol";
import "../interfaces/IYexFTOPair.sol";
import "../interfaces/IHenloDexPair.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./../libraries/TransferHelper.sol";

abstract contract BurnableHook is IYexFTOHook {
    function claimLP(address ftoPair, address lpToken) external override {
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

        ERC20Burnable(launchedToken).burn(launchedAmount);
    }
}
