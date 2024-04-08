// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

interface IYexFTOFacade {
    function factory() external view returns (address);

    function deposit(
        address baseToken,
        address fairToken,
        uint256 baseTokenAmount,
        uint256 fairTokenAmount
    ) external;

    function withdraw(address baseToken, address fairToken) external;

    function claimLP(address baseToken, address fairToken) external;
    
    function pause(address baseToken, address fairToken) external;

    function resume(address baseToken, address fairToken) external;

    function refundBaseToken(
        address baseToken,
        address fairToken
    ) external;

    function claimableLP(
        address baseToken,
        address fairToken
    ) external view returns (uint256);

    function getFTOPairProvider(
        address baseToken,
        address fairToken
    ) external view returns (address provider);

    function getFTOPair(
        address baseToken,
        address fairToken
    ) external view returns (address pair);

    function getFTOState(
        address baseToken,
        address fairToken
    ) external view returns (uint256 state);
}
