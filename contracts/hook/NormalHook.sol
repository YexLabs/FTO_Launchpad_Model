// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../interfaces/IYexFTOHook.sol";
import "../interfaces/IYexFTOFactoryV3.sol";
import "./../libraries/TransferHelper.sol";

abstract contract NormalHook is IYexFTOHook {
    address public ftoFactory;

    constructor(address _ftoFactory) {
        ftoFactory = _ftoFactory;
    }

    function createFTO(
        address raisedToken,
        string calldata name,
        string calldata symbol,
        uint256 amount,
        uint256 launchedTokenPercent,
        address poolHandler,
        uint256 rasingCycle,
        bytes calldata data
    ) public virtual {
        IYexFTOFactoryV3(ftoFactory).createFTO(
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

    function afterAddLiquidity(
        address ftoPair,
        address lpToken,
        uint256 lpAmount
    ) public virtual override {
        TransferHelper.safeTransferFrom(
            lpToken,
            ftoPair,
            address(this),
            lpAmount
        );
    }
}
