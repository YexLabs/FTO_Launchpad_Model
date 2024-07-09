// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/Ownable.sol";
import "../interfaces/IYexFTOFacadeV2.sol";
import "../interfaces/IYexFTOPairV2.sol";
import "../libraries/YexFTOLibrary.sol";
import "../libraries/TransferHelper.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

contract YexFTOFacadeV2 is IYexFTOFacadeV2, Ownable {
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
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        provider = IYexFTOPairV2(pair).launchedTokenProvider();
    }

    function getFTOState(
        address raisedToken,
        address launchedToken
    ) public view override returns (uint256 state) {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        state = uint256(IYexFTOPairV2(pair).FTOState());
    }

    function deposit(
        address raisedToken,
        address launchedToken,
        uint256 raisedTokenAmount,
        uint256 launchedTokenAmount
    ) external override {
        _deposit(
            raisedToken,
            launchedToken,
            raisedTokenAmount,
            launchedTokenAmount
        );
    }

    function withdraw(
        address raisedToken,
        address launchedToken
    ) external override {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        IYexFTOPairV2(pair).withdraw(msg.sender);
    }

    function claimLP(
        address raisedToken,
        address launchedToken
    ) external override {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        IYexFTOPairV2(pair).claimLP(msg.sender);
    }

    function claimLaunchedToken(
        address raisedToken,
        address launchedToken
    ) external override {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        IYexFTOPairV2(pair).claimLaunchedToken(msg.sender);
    }

    function refundRaisedToken(
        address raisedToken,
        address launchedToken
    ) external override {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        IYexFTOPairV2(pair).refundRaisedToken(msg.sender);
    }

    function claimableLP(
        address raisedToken,
        address launchedToken
    ) external view override returns (uint256) {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        return IYexFTOPairV2(pair).claimableLP(msg.sender);
    }

    function claimableLaunchedToken(
        address raisedToken,
        address launchedToken
    ) external view override returns (uint256) {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        return IYexFTOPairV2(pair).claimableLaunchedToken(msg.sender);
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
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        // transfer amount to pair
        if (raisedTokenAmount > 0) {
            TransferHelper.safeTransferFrom(
                raisedToken,
                msg.sender,
                pair,
                raisedTokenAmount
            );
            IYexFTOPairV2(pair).depositRaisedToken(msg.sender, raisedTokenAmount);
        }
        if (launchedTokenAmount > 0) {
            TransferHelper.safeTransferFrom(
                launchedToken,
                msg.sender,
                pair,
                launchedTokenAmount
            );
            IYexFTOPairV2(pair).depositLaunchedToken(
                msg.sender,
                launchedTokenAmount
            );
        }
    }
}
