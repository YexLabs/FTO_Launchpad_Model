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
        address baseToken,
        address fairToken
    ) public view returns (address pair) {
        pair = YexFTOLibrary.pairFor(factory, baseToken, fairToken);
    }

    function getFTOPairProvider(
        address baseToken,
        address fairToken
    ) public view returns (address provider) {
        address pair = YexFTOLibrary.pairFor(factory, baseToken, fairToken);
        provider = IYexFTOPair(pair).fairTokenProvider();
    }

    function getFTOState(
        address baseToken,
        address fairToken
    ) public view override returns (uint256 state) {
        address pair = YexFTOLibrary.pairFor(factory, baseToken, fairToken);
        state = uint256(IYexFTOPair(pair).FTOState());
    }

    function deposit(
        address baseToken,
        address fairToken,
        uint256 baseTokenAmount,
        uint256 fairTokenAmount
    ) external override {
        _deposit(baseToken, fairToken, baseTokenAmount, fairTokenAmount);
    }

    function withdraw(address baseToken, address fairToken) external override {
        require(
            getFTOPairProvider(baseToken, fairToken) == msg.sender,
            "only provider can withdraw"
        );
        address pair = YexFTOLibrary.pairFor(factory, baseToken, fairToken);
        IYexFTOPair(pair).withdraw(msg.sender);
    }

    function claimLP(address baseToken, address fairToken) external override {
        address pair = YexFTOLibrary.pairFor(factory, baseToken, fairToken);
        require(
            getFTOPairProvider(baseToken, fairToken) == msg.sender ||
                IYexFTOPair(pair).baseTokenDeposit(msg.sender) != 0,
            "only fairToken provider or baseToken depositer can claim."
        );
        IYexFTOPair(pair).claimLP(msg.sender);
    }

    function refundBaseToken(
        address baseToken,
        address fairToken
    ) external override {
        address pair = YexFTOLibrary.pairFor(factory, baseToken, fairToken);
        require(
            getFTOPairProvider(baseToken, fairToken) == msg.sender ||
                IYexFTOPair(pair).baseTokenDeposit(msg.sender) != 0,
            "only baseToken depositer can get refund."
        );
        IYexFTOPair(pair).refundBaseToken(msg.sender);
    }

    function pause(address baseToken, address fairToken) external override {
        require(
            getFTOPairProvider(baseToken, fairToken) == msg.sender,
            "only provider can pause"
        );
        address pair = YexFTOLibrary.pairFor(factory, baseToken, fairToken);
        IYexFTOPair(pair).pause();
    }

    function resume(address baseToken, address fairToken) external override {
        require(
            getFTOPairProvider(baseToken, fairToken) == msg.sender,
            "only provider can resume"
        );
        address pair = YexFTOLibrary.pairFor(factory, baseToken, fairToken);
        IYexFTOPair(pair).resume();
    }

    function claimableLP(
        address baseToken,
        address fairToken
    ) external view override returns (uint256) {
        address pair = YexFTOLibrary.pairFor(factory, baseToken, fairToken);
        return IYexFTOPair(pair).claimableLP(msg.sender);
    }

    function _deposit(
        address baseToken,
        address fairToken,
        uint256 baseTokenAmount,
        uint256 fairTokenAmount
    ) internal {
        require(
            baseTokenAmount > 0 || fairTokenAmount > 0,
            "INSUFFICIENT_INPUT_AMOUNT"
        );
        address pair = YexFTOLibrary.pairFor(factory, baseToken, fairToken);
        // transfer amount to pair
        if (baseTokenAmount > 0) {
            TransferHelper.safeTransferFrom(
                baseToken,
                msg.sender,
                pair,
                baseTokenAmount
            );
            IYexFTOPair(pair).depositBaseToken(msg.sender, baseTokenAmount);
        }
        if (fairTokenAmount > 0) {
            TransferHelper.safeTransferFrom(
                fairToken,
                msg.sender,
                pair,
                fairTokenAmount
            );
            IYexFTOPair(pair).depositFairToken(msg.sender, fairTokenAmount);
        }
    }
}
