// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../interfaces/IYexFTOPair.sol";
import "../interfaces/IYexFTOFactoryV3.sol";
import "./BurnableHook.sol";
import "./NormalHook.sol";
import "./VestingHook.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IHenloDexPair.sol";
import "./../libraries/TransferHelper.sol";

contract CustomHook is VestingHook, BurnableHook, NormalHook, AccessControl {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    address public ftoFactory;
    mapping(address => uint256) private _erc20Released;

    constructor(address _ftoFactory) {
        ftoFactory = _ftoFactory;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(FACTORY_ROLE, _ftoFactory);
    }

    function execute(
        address ftoPair,
        bytes calldata data
    ) external override(IYexFTOHook, VestingHook) onlyRole(FACTORY_ROLE) {
        VestingHook(address(this)).execute(ftoPair, data);
    }

    function afterAddLiquidity(
        address ftoPair,
        address lpToken,
        uint256 lpAmount
    ) external override(IYexFTOHook, VestingHook) onlyRole(FACTORY_ROLE) {
        VestingHook(address(this)).afterAddLiquidity(
            ftoPair,
            lpToken,
            lpAmount
        );
    }
}
