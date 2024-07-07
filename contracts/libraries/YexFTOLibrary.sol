// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.16;

import "../interfaces/IHenloDexPair.sol";

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
                            hex"88561b0591c2532981ed560516d411c10400a7b5998dccb5770ea18ac1dd9797" // init code hash
                        )
                    )
                )
            )
        );
    }
}
