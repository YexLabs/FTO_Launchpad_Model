// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

interface IYexFTOFacade {
    function factory() external view returns (address);

    function deposit(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external;

    function withdraw(address tokenA, address tokenB) external;

    function claimLP(address tokenA, address tokenB) external;

    function claimableLP(
        address tokenA,
        address tokenB
    ) external view returns (uint256);

    function getFTOPairProvider(
        address tokenA,
        address tokenB
    ) external view returns (address provider);

    function getFTOPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function getFTOState(
        address tokenA,
        address tokenB
    ) external view returns (uint256 state);
}
