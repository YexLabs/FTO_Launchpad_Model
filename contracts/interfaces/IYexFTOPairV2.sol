// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../libraries/AutomationCompatibleInterface.sol";

interface IYexFTOPairV2 is AutomationCompatibleInterface {
    enum Status {
        Success,
        Failed,
        Paused,
        Processing
    }

    event DepositRaisedToken(address indexed depositer, uint);
    event ClaimLP(address indexed claimer, uint);
    event Refund(address indexed depositer, uint);
    event Paused(uint timestamp);
    event Resumed(uint timestamp);
    event ClaimLaunchedToken(address claimer, uint256 amount);

    function depositRaisedToken(address depositer, uint256 amount) external;

    function claimLP(address claimer) external;

    function claimLaunchedToken(address claimer) external;

    function pause() external;

    function resume() external;

    function refundRaisedToken(address depositer) external;

    function claimableLP(address claimer) external view returns (uint256);

    function claimableLaunchedToken(
        address claimer
    ) external view returns (uint256);

    function launchedTokenProvider() external view returns (address);

    function raisedTokenDeposit(address) external view returns (uint256);

    function FTOState() external view returns (Status);

    function withdrawFee(address feeTo) external;

    function raisedToken() external view returns (address);

    function launchedToken() external view returns (address);

    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view returns (bool, bytes memory);

    function performUpkeep(bytes calldata) external;
}
