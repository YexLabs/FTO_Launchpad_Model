// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "./CustomHook.sol";
import "../libraries/HookMiner.sol";

contract CreateHooks {
    uint256 internal constant EXECUTE_FLAG = 1 << 159;
    uint256 internal constant LIQUIDITY_HOOK_OP_FLAG = 1 << 158;
    uint256 internal constant BURNABLE_FLAG = 1 << 157;

    address public pairAddr;

    constructor() {}

    function findSalt(
        address _ftoFactory
    ) external view returns (address pair, bytes32 salt) {
        uint160 flags = uint160(
            EXECUTE_FLAG | LIQUIDITY_HOOK_OP_FLAG | BURNABLE_FLAG
        );
        (pair, salt) = HookMiner.find(
            address(this),
            flags,
            type(CustomHook).creationCode,
            abi.encode(address(_ftoFactory))
        );
    }

    function createHook(
        bytes32 salt,
        address _ftoFactory
    ) external returns (address pair) {
        bytes memory bytecode = abi.encodePacked(
            type(CustomHook).creationCode,
            abi.encode(_ftoFactory)
        );
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // CustomHook(pair).createFTO(
        //     address(this),
        //     "test",
        //     "test",
        //     0,
        //     10,
        //     address(this),
        //     12,
        //     "0x"
        // );
        pairAddr = pair;
    }
}
