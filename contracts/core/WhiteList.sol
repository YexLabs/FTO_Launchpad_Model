// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/Ownable.sol";

abstract contract WhiteList is Ownable {
    mapping(address => bool) whiteListMapping;

    modifier onlyWhiteList() {
        _checkWhiteList(msg.sender);
        _;
    }

    function _checkWhiteList(address user) internal view virtual {
        require(
            whiteListMapping[user] == true,
            "WhiteList: only whiteList can create"
        );
    }

    function addWhiteList(address user) external onlyOwner {
        whiteListMapping[user] = true;
    }

    function batchAddWhiteList(address[] memory user) external onlyOwner {
        for (uint i = 0; i < user.length; i++) {
            whiteListMapping[user[i]] = true;
        }
    }

    function removeWhiteList(address user) external onlyOwner {
        whiteListMapping[user] = false;
    }
}
