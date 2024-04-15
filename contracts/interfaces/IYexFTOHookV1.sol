// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

interface IYexFTOHookV1 {
    struct FeeInfo {
        address feeToken;
        address provider;
        // launchTokenRatio = 1 Origin Token * 10 **  Orign Token deciaml
        uint256 feeTokenRatio;
        uint256 lockTime;
        uint256 collectedFeeAmount;
        uint256 withdrawnFeeAmount;
    }

    event Locked(
        address indexed originToken,
        address indexed launchedToken,
        uint timestamp
    );

    event Swap(
        address indexed launchedToken,
        address indexed originToken,
        uint256 _amount
    );

    event WithdrawFeeToken(
        address indexed originToken,
        address indexed launchedToken,
        uint256 amount
    );

    function factory() external view returns (address);

    function swapLaunchedTokenForOriginToken(
        address launchedToken,
        address originToken,
        uint256 _amount
    ) external;

    function withdrawFeeToken(
        address originToken,
        address launchedToken,
        uint256 amount
    ) external;


}
