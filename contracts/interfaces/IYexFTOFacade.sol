// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

interface IYexFTOFacade {
    function factory() external view returns (address);

    function deposit(
        address raisedToken,
        address launchedToken,
        uint256 raisedTokenAmount,
        uint256 launchedTokenAmount
    ) external;

    function withdraw(address raisedToken, address launchedToken) external;

    function claimLP(address raisedToken, address launchedToken, uint256 claimAmount) external;

    function refundRaisedToken(
        address raisedToken,
        address launchedToken
    ) external;

    function claimableLP(
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
