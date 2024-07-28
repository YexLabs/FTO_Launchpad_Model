// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.16;

import "../interfaces/IHenloDexPair.sol";

import "./SafeMathUniswap.sol";

library YexFTOLibrary {
    using SafeMathUniswap for uint;

    error IdenticalAddress(address launchedToken);
    error TokenAddressIsZero();

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(
        address raisedToken,
        address launchedToken
    ) internal pure returns (address token0, address token1) {
        if (raisedToken == launchedToken) {
            revert IdenticalAddress(launchedToken);
        }

        (token0, token1) = raisedToken < launchedToken
            ? (raisedToken, launchedToken)
            : (launchedToken, raisedToken);

        if (token0 == address(0)) {
            revert TokenAddressIsZero();
        }
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
                            hex"3646b19eee2cf5bc2f143dd7dda1681be956c26e2cbe9961c2fc2acea9d1e6ce" // init code hash
                        )
                    )
                )
            )
        );
    }
}
