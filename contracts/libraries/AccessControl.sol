// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Context.sol";

/**
 * @title AccessControl
 * @dev Contract module that allows children to implement role-based access control mechanisms.
 */
contract AccessControl is Context {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts with a standardized message.
     */
    modifier onlyRole(bytes32 role) {
        require(hasRole(role, _msgSender()), "AccessControl: sender requires permission");
        _;
    }

    /**
     * @dev Checks if an account has been granted a specific role.
     */
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Returns the admin role that controls a specific role.
     */
    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants a specific role to an account. Only accounts with the admin role can call this function.
     */
    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes a specific role from an account. Only accounts with the admin role can call this function.
     */
    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Grants a specific role to an account.
     */
    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes a specific role from an account.
     */
    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev Sets up a specific role for an account during contract deployment.
     */
    function _setupRole(bytes32 role, address account) internal {
        _grantRole(role, account);
    }

    /**
     * @dev Sets the admin role for a specific role.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        _roles[role].adminRole = adminRole;
    }
}
