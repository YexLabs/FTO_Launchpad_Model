// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../interfaces/IYexFTOHook.sol";
import "../interfaces/IYexFTOFactoryV2.sol";
import "./../libraries/TransferHelper.sol";
import "./../libraries/YexFTOHook.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

abstract contract NormalHook is ERC165, IYexFTOHook {
    error NotImplemented();

    uint256 internal lock;
    address public immutable ftoFactory;

    constructor(address _ftoFactory) {
        ftoFactory = _ftoFactory;

        YexFTOHook.validateHookAddress(address(this), getFlags());
    }

    function getFlags() public pure virtual returns (YexFTOHook.Flags memory);

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IYexFTOHook).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function createFTO(
        address raisedToken,
        string calldata name,
        string calldata symbol,
        uint256 amount,
        uint256 launchedTokenPercent,
        address poolHandler,
        uint256 raisingCycle,
        bytes calldata data
    ) public virtual {
        IYexFTOFactoryV2(ftoFactory).createFTO(
            raisedToken,
            name,
            symbol,
            amount,
            launchedTokenPercent,
            poolHandler,
            raisingCycle,
            data
        );
    }

    function withdrawRaisedToken(
        address /*ftoPair*/
    ) external virtual {
        revert NotImplemented();
    }

    function execute(bytes calldata /*params*/) external virtual {
        revert NotImplemented();
    }

    function liquidityHookOp(
        address /*lpToken*/,
        uint256 /*lpAmount*/
    ) public virtual override {
        revert NotImplemented();
    }
}
