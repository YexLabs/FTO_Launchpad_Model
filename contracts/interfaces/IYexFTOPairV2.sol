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

    struct FtoPairTokenInfo {
        address raisedToken;
        address launchedToken;
        address lpToken;
    }

    event DepositRaisedToken(address indexed depositer, uint);
    event ClaimLP(address indexed claimer, uint);
    event Refund(address indexed depositer, uint);
    event Paused(uint timestamp);
    event Resumed(uint timestamp);
    event ClaimLaunchedToken(address claimer, uint256 amount);

    function depositRaisedToken(address depositor, uint256 amount) external;

    function withdrawRaisedToken() external;

    function claimLP(address claimer) external;

    function claimLaunchedToken(address claimer) external;

    function pause() external;

    function resume() external;

    function refundRaisedToken() external;

    function claimableLP(address claimer) external view returns (uint256);

    function claimableLaunchedToken(address claimer) external view returns (uint256);

    function launchedTokenProvider() external view returns (address);

    function raisedTokenDeposit(address) external view returns (uint256);

    function FTOState() external view returns (Status);

    function withdrawFee(address feeTo) external;

    function getFtoPairTokenInfo() external view returns (FtoPairTokenInfo memory);
}