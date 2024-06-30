// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../interfaces/IYexFTOHook.sol";
import "../interfaces/IYexFTOFactoryV3.sol";

abstract contract NormalHook is IYexFTOHook {
    function createFTO(
        address raisedToken,
        string calldata name,
        string calldata symbol,
        uint256 amount,
        uint256 launchedTokenPercent,
        address poolHandler,
        uint256 rasingCycle,
        bytes calldata data
    ) external {
        IYexFTOFactoryV3(IYexFTOHook(address(this)).ftoFactory()).createFTO(
            raisedToken,
            name,
            symbol,
            amount,
            launchedTokenPercent,
            poolHandler,
            rasingCycle,
            data
        );
    }
}
