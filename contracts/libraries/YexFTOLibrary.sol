// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.16;

import "../interfaces/IUniswapV2Pair.sol";

import "./SafeMathUniswap.sol";

library YexFTOLibrary {
    using SafeMathUniswap for uint;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(
        address raisedToken,
        address launchedToken
    ) internal pure returns (address token0, address token1) {
        require(
            raisedToken != launchedToken,
            "YexFTOLibrary: IDENTICAL_ADDRESSES"
        );
        (token0, token1) = raisedToken < launchedToken
            ? (raisedToken, launchedToken)
            : (launchedToken, raisedToken);
        require(token0 != address(0), "YexFTOLibrary: ZERO_ADDRESS");
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(
        address factory,
        address raisedToken,
        address launchedToken
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(
            raisedToken,
            launchedToken
        );
        pair = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"31b05e2391e5fd302184fcf5dfd94e6d551c455c6cc5cc7290b371cfe0e01b9f" // init code hash
                        )
                    )
                )
            )
        );
    }
}
