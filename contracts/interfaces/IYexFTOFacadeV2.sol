// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

interface IYexFTOFacadeV2 {
    function factory() external view returns (address);

    function deposit(
        address raisedToken,
        address launchedToken,
        uint256 raisedTokenAmount
    ) external;

    function claimLP(address raisedToken, address launchedToken) external;

    function claimLaunchedToken(address raisedToken, address launchedToken) external;

    function claimableLP(
        address raisedToken,
        address launchedToken
    ) external view returns (uint256);

    function claimableLaunchedToken(
        address raisedToken,
        address launchedToken
    ) external view returns (uint256);

    function getFTOPairProvider(
        address raisedToken,
        address launchedToken
    ) external view returns (address provider);

    function getFTOPair(
        address raisedToken,
        address launchedToken
    ) external view returns (address pair);

    function getFTOState(
        address raisedToken,
        address launchedToken
    ) external view returns (uint256 state);
}
