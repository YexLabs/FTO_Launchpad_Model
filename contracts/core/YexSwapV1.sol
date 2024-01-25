// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/ERC20.sol";

contract YexLP is ERC20 {
    address dexAddr;

    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        dexAddr = msg.sender;
    }

    modifier onlyDEX() {
        require(
            msg.sender == dexAddr,
            "YexLP: Only DEX can call this function"
        );
        _;
    }

    function mint(address to, uint256 amount) external onlyDEX {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyDEX {
        _burn(from, amount);
    }
}

contract YexSwapV1 {
    enum PoolType {
        Stable,
        ConstantK
    }

    struct poolInfo {
        IERC20 token0;
        IERC20 token1;
        uint112 reserve0;
        uint112 reserve1;
        uint kValue;
        PoolType poolType;
        YexLP lpToken;
    }
    mapping(address => mapping(address => poolInfo)) public poolInfoMap;

    address public feeTo;

    constructor(address _feeTo) {
        feeTo = _feeTo;
    }
}
