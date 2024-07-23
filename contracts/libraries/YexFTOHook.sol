// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title Library for LaunchPad Hook
 * @dev This library provides two basic functions for a given address:
 *      - Using IERC165, it checks if the given address is a hook contract address.
 *      - Assuming the given address is a hook contract address, it checks if the address has specific functions.
 */
library YexFTOHook {
    /// @dev As per the ERC-165 spec, no interface should ever match 0xffffffff
    bytes4 private constant _INTERFACE_ID_INVALID = 0xffffffff;

    uint256 internal constant EXECUTE_FLAG = 1 << 159;
    uint256 internal constant LIQUIDITY_HOOK_OP_FLAG = 1 << 158;
    uint256 internal constant BURNABLE_FLAG = 1 << 157;

    /**
     * @dev If the hook has a vesting function, [execute] and [liquidityHookOp] are true.
     * If the hook has a remove/burn function, [execute] and [burnable] are true.
     */
    struct Flags {
        bool execute;
        bool liquidityHookOp;
        bool burnable;
    }

    error InvalidHookAddress();

    /**
     * @dev If the 160th bit of [hook] is 1, it is determined that it has the execute function.
     */
    function hasExecute(address hook) internal pure returns (bool) {
        return uint256(uint160(address(hook))) & EXECUTE_FLAG != 0;
    }

    /**
     * @dev If the 159th bit of [hook] is 1, it is determined that it has the liquidityHookOp function.
     */
    function hasLiquidityHookOp(address hook) internal pure returns (bool) {
        return uint256(uint160(address(hook))) & LIQUIDITY_HOOK_OP_FLAG != 0;
    }

    /**
     * @dev If the 158th bit of [hook] is 1, it is determined that it has the remove/burn function.
     */
    function hasBurnable(address hook) internal pure returns (bool) {
        return uint256(uint160(address(hook))) & BURNABLE_FLAG != 0;
    }

    /**
     * @dev It checks if the hook's address meets the conditions of the hook flags.
     * If the validation fails, it reverts.
     * @param hook the address of hook contract
     * @param flags A Flags-type variable for validating the hook contract address
     */
    function validateHookAddress(address hook, Flags memory flags) internal pure {
        if(
            flags.execute != hasExecute(hook) ||
            flags.liquidityHookOp != hasLiquidityHookOp(hook) ||
            flags.burnable != hasBurnable(hook)) {
            revert InvalidHookAddress();
        }
    }

    /**
     * @dev Returns true if `account` supports the interface defined by
     * `interfaceId`. Support for {IERC165} itself is queried automatically.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsInterface(address account, bytes4 interfaceId) internal view returns (bool) {
        // query support of both ERC165 as per the spec and support of _interfaceId
        return supportsERC165(account) && supportsERC165InterfaceUnchecked(account, interfaceId);
    }

    /**
     * @dev Returns true if `account` supports the {IERC165} interface.
     */
    function supportsERC165(address account) internal view returns (bool) {
        // Any contract that implements ERC165 must explicitly indicate support of
        // InterfaceId_ERC165 and explicitly indicate non-support of InterfaceId_Invalid
        return
            supportsERC165InterfaceUnchecked(account, type(IERC165).interfaceId) &&
            !supportsERC165InterfaceUnchecked(account, _INTERFACE_ID_INVALID);
    }

    /**
     * @notice Query if a contract implements an interface, does not check ERC165 support
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the contract at account indicates support of the interface with
     * identifier interfaceId, false otherwise
     * @dev Assumes that account contains a contract that supports ERC165, otherwise
     * the behavior of this method is undefined. This precondition can be checked
     * with {supportsERC165}.
     *
     * Some precompiled contracts will falsely indicate support for a given interface, so caution
     * should be exercised when using this function.
     *
     * Interface identification is specified in ERC-165.
     */
    function supportsERC165InterfaceUnchecked(address account, bytes4 interfaceId) internal view returns (bool) {
        // prepare call
        bytes memory encodedParams = abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId);

        // perform static call
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly {
            success := staticcall(30000, account, add(encodedParams, 0x20), mload(encodedParams), 0x00, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0x00)
        }

        return success && returnSize >= 0x20 && returnValue > 0;
    }
}