// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../interfaces/IYexFTOPair.sol";
import "./VestingHook.sol";
import "./BurnableHook.sol";
import "../interfaces/IHenloDexPair.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./../libraries/TransferHelper.sol";

contract CustomHook is VestingHook, BurnableHook {
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
        require(
            getPair[ftoPair].beneficiaryAddress == address(0),
            "pair have added."
        );

        (
            address beneficiaryAddress,
            uint64 startTimestamp,
            uint64 durationSeconds
        ) = abi.decode(data, (address, uint64, uint64));

        require(startTimestamp > 0, "vesting time cannot less than 0");

        getPair[ftoPair] = VestingInfo(
            beneficiaryAddress,
            startTimestamp,
            durationSeconds,
            address(0)
        );
    }

    function afterAddLiquidity(
        address ftoPair,
        address lpToken,
        uint256 lpAmount
    ) external override(IYexFTOHook, VestingHook) onlyRole(FACTORY_ROLE) {
        TransferHelper.safeTransferFrom(
            lpToken,
            ftoPair,
            address(this),
            lpAmount
        );
        getPair[ftoPair].lpToken = lpToken;
    }
}
