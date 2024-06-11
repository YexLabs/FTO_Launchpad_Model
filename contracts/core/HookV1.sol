// // SPDX-License-Identifier: GPL-3.0
// pragma solidity ^0.8.16;

// import "../interfaces/IYexFTOFactory.sol";
// import "./YexFTOPair.sol";
// import "../interfaces/IERC20.sol";
// import "../interfaces/IHook.sol";

// contract HookV1 is IHook {
//     address public factory;

//     mapping(address => mapping(address => uint)) locks;
//     mapping(address => mapping(address => uint256)) lockAmounts;
//     mapping(address => mapping(address => address)) feeTokens;
//     mapping(address => mapping(address => address)) providers;
//     mapping(address => mapping(address => mapping(address => uint))) fees;

//     constructor(address _factory) {
//         factory = _factory;
//     }

//     function launch(
//         address originToken,
//         address raisedToken, // maybe usdt
//         address feeToken,
//         string calldata launchedTokenName,
//         string calldata launchedTokensymbol,
//         uint256 _amount,
//         address poolHandler,
//         uint256 lockTime,
//         uint256 raisingCycle
//     ) external {
//         // 1. receive and lock originToken
//         TransferHelper.safeTransferFrom(
//             originToken,
//             msg.sender,
//             address(this),
//             _amount
//         );

//         // 2. create fto
//         address pair = IYexFTOFactory(factory).createFTO(
//             msg.sender,
//             raisedToken,
//             launchedTokenName,
//             launchedTokensymbol,
//             _amount,
//             poolHandler,
//             raisingCycle
//         );

//         address launchedToken = YexFTOPair(pair).launchedToken();

//         locks[originToken][launchedToken] = block.timestamp + lockTime;
//         lockAmounts[originToken][launchedToken] = _amount;
//         providers[originToken][launchedToken] = msg.sender;
//         feeTokens[originToken][launchedToken] = feeToken;

//         // emit some envent
//         emit Launch(originToken, launchedToken, _amount);
//     }

//     function withdraw(
//         address originToken,
//         address launchedToken,
//         uint256 feeAmount
//     ) external override {
//         address provider = providers[originToken][launchedToken];
//         require(provider == msg.sender, "only provider can withdraw fee.");
//         require(
//             feeAmount <= fees[originToken][launchedToken][provider],
//             "not enough fee."
//         );
//         IERC20(originToken).transfer(msg.sender, feeAmount);
//     }

//     function unlock(
//         address originToken,
//         address launchedToken,
//         uint256 _amount
//     ) external override {
//         // 1. check wether locktime is done and amount is enough.
//         require(
//             locks[originToken][launchedToken] >= block.timestamp,
//             "lock time not done."
//         );
//         require(
//             IERC20(originToken).balanceOf(address(this)) >= _amount,
//             "not enough amount."
//         );
//         require(
//             lockAmounts[originToken][launchedToken] >= _amount,
//             "not enough amount."
//         );

//         // 2. receive launchedToken + some fee (like 1usdt)

//         uint256 _fee = _calculateFee(originToken, launchedToken, _amount);

//         TransferHelper.safeTransferFrom(
//             launchedToken,
//             msg.sender,
//             address(this),
//             _amount
//         ); // or maybe we can just burn the launchedToken
//         TransferHelper.safeTransferFrom(
//             feeToken,
//             msg.sender,
//             address(this),
//             _fee
//         );

//         fees[originToken][launchedToken][
//             providers[originToken][launchedToken]
//         ] += _fee;

//         // 3. send originToken
//         IERC20(originToken).transfer(msg.sender, _amount);
//         lockAmounts[originToken][launchedToken] -= _amount;
//     }

//     function calculateFee(
//         address originToken,
//         address launchedToken,
//         uint256 amount
//     ) external view override {
//         return 10 ** 18;
//     }
// }
