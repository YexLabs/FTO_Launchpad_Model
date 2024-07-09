// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../interfaces/IYexFTOHook.sol";

library YexFTOHook {
    uint256 internal constant EXECUTE_FLAG = 1 << 159;
    uint256 internal constant AFTER_ADD_LIQUIDITY_FLAG = 1 << 158;
    uint256 internal constant BURNABLE_FLAG = 1 << 157;

    struct Flags {
        bool execute;
        bool afterAddLiquidity;
        bool burnable;
    }

    error InvalidHookAddress();

    function hasExecute(IYexFTOHook hook) internal pure returns (bool) {
        return uint256(uint160(address(hook))) & EXECUTE_FLAG != 0;
    }

    function hasAfterAddLiquidity(IYexFTOHook hook) internal pure returns (bool) {
        return uint256(uint160(address(hook))) & AFTER_ADD_LIQUIDITY_FLAG != 0;
    }

    function hasBurnable(IYexFTOHook hook) internal pure returns (bool) {
        return uint256(uint160(address(hook))) & BURNABLE_FLAG != 0;
    }

    function isValidHookAddress(IYexFTOHook hook) internal pure returns (bool) {
        return uint160(address(hook)) >= BURNABLE_FLAG;
    }

    function validateHookAddress(IYexFTOHook hook, Flags memory flags) internal pure {
        if(
            flags.execute != hasExecute(hook) ||
            flags.afterAddLiquidity != hasAfterAddLiquidity(hook) ||
            flags.burnable != hasBurnable(hook)) {
            revert InvalidHookAddress();
        }
    }
}