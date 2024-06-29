// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../interfaces/IYexFTOHook.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "./../libraries/TransferHelper.sol";

contract VestingHook is IYexFTOHook, AccessControl {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    address public ftoFactory;

    mapping(address => address) public getPair;

    constructor(address _ftoFactory) {
        ftoFactory = _ftoFactory;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(FACTORY_ROLE, _ftoFactory);
    }

    function execute(
        address _ftoPair,
        bytes calldata data
    ) external override onlyRole(FACTORY_ROLE) {
        require(getPair[_ftoPair] == address(0), "pair have added.");

        (
            address beneficiaryAddress,
            uint64 startTimestamp,
            uint64 durationSeconds
        ) = abi.decode(data, (address, uint64, uint64));

        require(startTimestamp > 0, "vesting time cannot less than 0");

        VestingWallet vestingWallet = new VestingWallet(
            beneficiaryAddress,
            startTimestamp,
            durationSeconds
        );
        getPair[_ftoPair] = address(vestingWallet);
    }

    function afterAddLiquidity(
        address ftoPair,
        address lpToken,
        uint256 lpAmount
    ) external override {
        TransferHelper.safeTransferFrom(
            lpToken,
            ftoPair,
            getPair[ftoPair],
            lpAmount
        );
    }
}
