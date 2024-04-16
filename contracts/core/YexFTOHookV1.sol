// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../interfaces/IYexFTOFactory.sol";
import "../interfaces/IYexFTOHookV1.sol";
import "./YexFTOPair.sol";
import "../interfaces/IERC20.sol";

contract YexFTOHookV1 is IYexFTOHookV1 {
    using SafeMath for uint256;

    address public factory;
    mapping(address => mapping(address => FeeInfo)) public feeInfoMap;

    constructor(address _factory) {
        factory = _factory;
    }

    function launch(
        address originToken,
        address raisedToken, // maybe usdt
        string calldata name,
        string calldata symbol,
        uint256 _amount,
        address poolHandler,
        uint256 raisingCycle,
        FeeInfo calldata feeInfo
    ) external {
        // 1. receive and lock originToken
        TransferHelper.safeTransferFrom(
            originToken,
            msg.sender,
            address(this),
            _amount
        );

        // 2. create fto
        address pair = IYexFTOFactory(factory).createFTO(
            msg.sender,
            raisedToken,
            name,
            symbol,
            _amount,
            poolHandler,
            raisingCycle
        );

        address launchedToken = YexFTOPair(pair).launchedToken();
        feeInfoMap[originToken][launchedToken] = FeeInfo(
            feeInfo.feeToken,
            msg.sender,
            feeInfo.feeTokenRatio,
            feeInfo.lockTime,
            0,
            0
        );

        emit Locked(originToken, launchedToken, feeInfo.lockTime);
    }

    function swapLaunchedTokenForOriginToken(
        address launchedToken,
        address originToken,
        uint256 _amount
    ) external override {
        FeeInfo memory feeInfo = feeInfoMap[originToken][launchedToken];
        // 1. check wether locktime is done and amount is enough.
        require(feeInfo.lockTime >= block.timestamp, "lock time not done.");
        require(
            IERC20(originToken).balanceOf(address(this)) >= _amount,
            "not enough amount."
        );

        // 2. receive launchedToken + some fee (like 1usdt)
        TransferHelper.safeTransferFrom(
            launchedToken,
            msg.sender,
            address(this),
            _amount
        ); // or maybe we can just burn the launchedToken

        if (feeInfo.feeToken != address(0) && feeInfo.feeTokenRatio > 0) {
            uint256 _feeAmount = _amount.div(10 ** 18).mul(
                feeInfo.feeTokenRatio
            );
            TransferHelper.safeTransferFrom(
                feeInfo.feeToken,
                msg.sender,
                address(this),
                _feeAmount
            );

            feeInfo.collectedFeeAmount += _feeAmount;
        }

        // 3. send originToken
        IERC20(originToken).transfer(msg.sender, _amount);
        emit Swap(launchedToken, originToken, _amount);
    }

    function withdrawFeeToken(
        address originToken,
        address launchedToken,
        uint256 amount
    ) external override {
        // Retrieve the FeeInfo struct once
        FeeInfo memory feeInfo = feeInfoMap[originToken][launchedToken];

        // Check permissions
        require(
            msg.sender == feeInfo.provider,
            "YexFTOHook:NOT_ALLOWED_PROVIDER"
        );

        // Check if feeToken is valid
        address feeToken = feeInfo.feeToken;
        require(feeToken != address(0), "YexFTOHook: ZERO_ADDRESS");

        // Check if the amount to withdraw is valid
        require(
            feeInfo.collectedFeeAmount > feeInfo.withdrawnFeeAmount,
            "Invalid Amount"
        );
        uint256 remainingFeeAmount = feeInfo.collectedFeeAmount -
            feeInfo.withdrawnFeeAmount;
        require(remainingFeeAmount >= amount, "Insufficient Fee");

        // Transfer feeToken to the caller
        IERC20(feeToken).transfer(msg.sender, amount);

        // Update withdrawnFeeAmount
        feeInfo.withdrawnFeeAmount += amount;

        // Update the FeeInfo struct in the mapping
        feeInfoMap[originToken][launchedToken] = feeInfo;

        // Emit event
        emit WithdrawFeeToken(originToken, launchedToken, amount);
    }
}
