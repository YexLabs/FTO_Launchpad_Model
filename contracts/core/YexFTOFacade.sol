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
        address raisedToken,
        address launchedToken
    ) public view returns (address pair) {
        pair = YexFTOLibrary.pairFor(factory, raisedToken, launchedToken);
    }

    function getFTOPairProvider(
        address raisedToken,
        address launchedToken
    ) public view returns (address provider) {
        address pair = YexFTOLibrary.pairFor(factory, raisedToken, launchedToken);
        provider = IYexFTOPair(pair).launchedTokenProvider();
    }

    function getFTOState(
        address raisedToken,
        address launchedToken
    ) public view override returns (uint256 state) {
        address pair = YexFTOLibrary.pairFor(factory, raisedToken, launchedToken);
        state = uint256(IYexFTOPair(pair).FTOState());
    }

    function deposit(
        address raisedToken,
        address launchedToken,
        uint256 raisedTokenAmount,
        uint256 launchedTokenAmount
    ) external override {
        _deposit(raisedToken, launchedToken, raisedTokenAmount, launchedTokenAmount);
    }

    function withdraw(address raisedToken, address launchedToken) external override {
        require(
            getFTOPairProvider(raisedToken, launchedToken) == msg.sender,
            "only provider can withdraw"
        );
        address pair = YexFTOLibrary.pairFor(factory, raisedToken, launchedToken);
        IYexFTOPair(pair).withdraw(msg.sender);
    }

    function claimLP(address raisedToken, address launchedToken) external override {
        address pair = YexFTOLibrary.pairFor(factory, raisedToken, launchedToken);
        require(
            getFTOPairProvider(raisedToken, launchedToken) == msg.sender ||
                IYexFTOPair(pair).raisedTokenDeposit(msg.sender) != 0,
            "only launchedToken provider or raisedToken depositer can claim."
        );
        IYexFTOPair(pair).claimLP(msg.sender);
    }

    function refundRaisedToken(
        address raisedToken,
        address launchedToken
    ) external override {
        address pair = YexFTOLibrary.pairFor(factory, raisedToken, launchedToken);
        require(
            getFTOPairProvider(raisedToken, launchedToken) == msg.sender ||
                IYexFTOPair(pair).raisedTokenDeposit(msg.sender) != 0,
            "only raisedToken depositer can get refund."
        );
        IYexFTOPair(pair).refundRaisedToken(msg.sender);
    }

    function pause(address raisedToken, address launchedToken) external override {
        require(
            getFTOPairProvider(raisedToken, launchedToken) == msg.sender,
            "only provider can pause"
        );
        address pair = YexFTOLibrary.pairFor(factory, raisedToken, launchedToken);
        IYexFTOPair(pair).pause();
    }

    function resume(address raisedToken, address launchedToken) external override {
        require(
            getFTOPairProvider(raisedToken, launchedToken) == msg.sender,
            "only provider can resume"
        );
        address pair = YexFTOLibrary.pairFor(factory, raisedToken, launchedToken);
        IYexFTOPair(pair).resume();
    }

    function claimableLP(
        address raisedToken,
        address launchedToken
    ) external view override returns (uint256) {
        address pair = YexFTOLibrary.pairFor(factory, raisedToken, launchedToken);
        return IYexFTOPair(pair).claimableLP(msg.sender);
    }

    function _deposit(
        address raisedToken,
        address launchedToken,
        uint256 raisedTokenAmount,
        uint256 launchedTokenAmount
    ) internal {
        require(
            raisedTokenAmount > 0 || launchedTokenAmount > 0,
            "INSUFFICIENT_INPUT_AMOUNT"
        );
        address pair = YexFTOLibrary.pairFor(factory, raisedToken, launchedToken);
        // transfer amount to pair
        if (raisedTokenAmount > 0) {
            TransferHelper.safeTransferFrom(
                raisedToken,
                msg.sender,
                pair,
                raisedTokenAmount
            );
            IYexFTOPair(pair).depositRaisedToken(msg.sender, raisedTokenAmount);
        }
        if (launchedTokenAmount > 0) {
            TransferHelper.safeTransferFrom(
                launchedToken,
                msg.sender,
                pair,
                launchedTokenAmount
            );
            IYexFTOPair(pair).depositLaunchedToken(msg.sender, launchedTokenAmount);
        }
    }
}
