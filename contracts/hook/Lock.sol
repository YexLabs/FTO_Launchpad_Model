// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

abstract contract Lock {
    uint256 private lock;

    error NotLocked();

    modifier onlyWhenLocked() virtual {
        if(lock == 0) {
            revert NotLocked();
        }
        _;
    }

    modifier lockFunction() virtual {
        lock = 1;
        _;
        lock = 0;
    }
}