// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/Ownable.sol";
import "../interfaces/IYexFTOFacade.sol";
import "../interfaces/IYexFTOPair.sol";
import "../libraries/YexFTOLibrary.sol";
import "../libraries/TransferHelper.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

contract YexFTOFacade is IYexFTOFacade, Ownable {
    address public immutable override factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function getFTOPair(
        address tokenA,
        address tokenB
    ) public view returns (address pair) {
        pair = YexFTOLibrary.pairFor(factory, tokenA, tokenB);
    }

    function getFTOPairProvider(
        address tokenA,
        address tokenB
    ) public view returns (address provider) {
        address pair = YexFTOLibrary.pairFor(factory, tokenA, tokenB);
        provider = IYexFTOPair(pair).tokenB_provider();
    }

    function getFTOState(
        address tokenA,
        address tokenB
    ) public view override returns (uint256 state) {
        address pair = YexFTOLibrary.pairFor(factory, tokenA, tokenB);
        state = uint256(IYexFTOPair(pair).ftoState());
    }

    function deposit(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external override {
        _deposit(tokenA, tokenB, amountA, amountB);
    }

    function withdraw(address tokenA, address tokenB) external override {
        require(
            getFTOPairProvider(tokenA, tokenB) == msg.sender,
            "only provider can withdraw"
        );
        address pair = YexFTOLibrary.pairFor(factory, tokenA, tokenB);
        IYexFTOPair(pair).withdraw(msg.sender);
    }

    function claimLP(address tokenA, address tokenB) external override {
        address pair = YexFTOLibrary.pairFor(factory, tokenA, tokenB);
        require(
            getFTOPairProvider(tokenA, tokenB) == msg.sender ||
                IYexFTOPair(pair).tokenA_deposit(msg.sender) != 0,
            "only tokenB provider or tokenA depositer can claim."
        );
        IYexFTOPair(pair).claimLP(msg.sender);
    }

    function claimableLP(
        address tokenA,
        address tokenB
    ) external view override returns (uint256) {
        address pair = YexFTOLibrary.pairFor(factory, tokenA, tokenB);
        return IYexFTOPair(pair).claimableLP(msg.sender);
    }

    function _deposit(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) internal {
        require(amountA > 0 || amountB > 0, "INSUFFICIENT_INPUT_AMOUNT");
        address pair = YexFTOLibrary.pairFor(factory, tokenA, tokenB);
        // transfer amount to pair
        if (amountA > 0) {
            TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
            IYexFTOPair(pair).depositTokenA(msg.sender, amountA);
        }
        if (amountB > 0) {
            TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
            IYexFTOPair(pair).depositTokenB(msg.sender, amountB);
        }
    }
}
