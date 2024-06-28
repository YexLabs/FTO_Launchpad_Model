// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/ERC20.sol";

contract USDT is ERC20 {
    constructor() ERC20("USDT", "USDT") {}

    mapping(address => bool) public faucetedList;

    function faucet() public {
        require(!faucetedList[msg.sender], "fauceted");
        faucetedList[msg.sender] = true;
        _mint(msg.sender, 900000000 * (10 ** decimals()));
    }
}
