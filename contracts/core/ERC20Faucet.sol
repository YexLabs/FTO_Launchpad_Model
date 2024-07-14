// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/ERC20.sol";

contract ERC20Faucet is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    mapping(address => bool) public faucetClaimer;

    function faucet() public {
        require(!faucetClaimer[msg.sender], "fauceted");
        faucetClaimer[msg.sender] = true;
        _mint(msg.sender, 300 * (10 ** decimals()));
    }
}
