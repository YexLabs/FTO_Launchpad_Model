// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

abstract contract Lock {
    uint256 private lock;

    modifier onlyWhenLocked() virtual {
        require(lock == 1, "Not locked");
        _;
    }

    modifier lockFunction() virtual {
        lock = 1;
        _;
        lock = 0;
    }
}