// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IHook {
    event Launch(address originToken, address launchedToken, uint256 amount);

    function withdraw(
        address originToken,
        address launchedToken,
        uint256 amount
    ) external;

    function unlock(
        address originToken,
        address launchedToken,
        uint256 amount
    ) external;

    function calculateFee(
        address originToken,
        address launchedToken,
        uint256 amount
    ) external view;
}
