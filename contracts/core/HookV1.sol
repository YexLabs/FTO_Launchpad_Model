// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../interfaces/IYexFTOFactory.sol";
import "./YexFTOPair.sol";
import "../interfaces/IERC20.sol";

contract HookV1 {
    address public factory;
    address public feeToken;
    // uint256 public feePercent;

    mapping(address => mapping(address => uint)) locks;
    mapping(address => mapping(address => address)) providers;
    mapping(address => mapping(address => mapping(address => uint))) fees;

    constructor(address _factory, address _feeToken) {
        factory = _factory;
        feeToken = _feeToken; // maybe usdt
        // feePercent = _feePercent; // like 5 so that we can get 5
    }

    function launch(
        address originToken,
        address raisedToken, // maybe usdt
        string calldata name,
        string calldata symbol,
        uint256 _amount,
        address poolHandler,
        uint256 lockTime,
        uint256 raisingCycle
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
            raisedToken,
            name,
            symbol,
            _amount,
            poolHandler,
            raisingCycle
        );

        address launchedToken = YexFTOPair(pair).launchedToken();
        locks[originToken][launchedToken] = block.timestamp + lockTime;
        providers[originToken][launchedToken] = msg.sender;

        // emit some envent
    }

    function withdraw(
        address originToken,
        address launchedToken,
        uint256 _amount
    ) {
        address provider = providers[originToken][launchedToken];
        require(provider == msg.sender, "only provider can withdraw fee.");
        require(
            _amount <= fees[originToken][launchedToken][provider],
            "not enough amount."
        );
        IERC20(originToken).transfer(msg.sender, _amount);
    }

    function unlock(
        address originToken,
        address launchedToken,
        uint256 _amount
    ) {
        // 1. check wether locktime is done and amount is enough.
        require(
            locks[originToken][launchedToken] >= block.timestamp,
            "lock time not done."
        );
        require(
            IERC20(originToken).balanceOf(address(this)) >= _amount,
            "not enough amount."
        );

        // 2. receive launchedToken + some fee (like 1usdt)

        uint256 _fee = _calculateFee(_amount);

        TransferHelper.safeTransferFrom(
            launchedToken,
            msg.sender,
            address(this),
            _amount
        ); // or maybe we can just burn the launchedToken
        TransferHelper.safeTransferFrom(
            feeToken,
            msg.sender,
            address(this),
            _fee
        );

        fees[originToken][launchedToken][
            providers[originToken][launchedToken]
        ] += _fee;

        // 3. send originToken
        IERC20(originToken).transfer(msg.sender, _amount);
    }

    function _calculateFee(uint256 amount) internal view {
        return 10 ** 18;
    }
}
