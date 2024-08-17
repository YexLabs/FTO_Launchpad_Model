// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title LaunchedToken contract
/// @notice The LaunchedToken to be used in the FTO Launchpad
contract YexFTOLaunchToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(
        string memory name_,
        string memory symbol_,
        address provider_
    ) ERC20(name_, symbol_) {
        /**
         * When the LaunchedToken is deployed by the FTOFactory,
         *      the FTOFactory obtains the MINTER_ROLE.
         *      the token launcher or hook obtains the BURNER_ROLE.
         */
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(BURNER_ROLE, provider_);
    }

    /// @dev This function is called only once by the FTOFactory.
    function mint(
        address to,
        uint256 amount
    ) public payable onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /// @dev This function can only be called by the token launcher or hook.
    /// The token launcher or hook can only burn their own balance.
    function burn(uint256 amount) public payable onlyRole(BURNER_ROLE) {
        _burn(_msgSender(), amount);
    }
}
