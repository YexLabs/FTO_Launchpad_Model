pragma solidity ^0.8.16;

import "./IERC20.sol";

interface IYexSwapV1 {
    function feeTo() external view returns (address);

    // function poolInfoMap(
    //     address baseToken,
    //     address fairToken
    // ) external view returns (poolInfo memory);

    // function createPool(
    //     address baseToken,
    //     address fairToken,
    //     uint112 baseTokenReserve,
    //     uint112 fairTokenReserve,
    //     PoolType poolType
    // ) external returns (address);

    function addLiquidity(
        address baseToken,
        address fairToken,
        uint256 baseTokenAmount,
        uint256 fairTokenAmount
    ) external returns (uint256 liquidity);
}
