// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../libraries/AutomationCompatibleInterface.sol";

interface IYexFTOPair is AutomationCompatibleInterface {
    enum Status {
        Success,
        Failed,
        Processing
    }
    event Deposit(address indexed depositer, uint);
    event Withdraw(address indexed withdrawer, uint);
    event ClaimLP(address indexed claimer, uint);

    function depositTokenA(address depositer, uint256 amountA) external;

    function depositTokenB(address depositer, uint256 amountB) external;

    function withdraw(address withdrawer) external;

    function claimLP(address claimer) external;

    function claimableLP(address claimer) external view returns (uint256);

    function tokenBProvider() external view returns (address);

    function tokenADeposit(address) external view returns (uint256);

    function FTOState() external view returns (Status);
}
