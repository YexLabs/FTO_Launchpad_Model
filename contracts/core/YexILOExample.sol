// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/ERC20.sol";
import "../libraries/Math.sol";
import "../libraries/Ownable.sol";
import "../libraries/Console.sol";

contract ERC20WithFaucet is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {}

    mapping(address => bool) public faucetedList;

    function faucet() public {
        require(!faucetedList[msg.sender], "fauceted");
        faucetedList[msg.sender] = true;
        _mint(msg.sender, 10 ** decimals());
    }
}

contract ERC20Mintable is ERC20, Ownable {
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract YexILOExample is ERC20("YexILOExampleLP", "ILOTestLP") {
    // Constant K value pool

    IERC20 public immutable baseToken; // tokenA is used to subscribe fairToken
    IERC20 public immutable fairToken; // fairToken is the issuer

    uint256 public baseTokenReserve;
    uint256 public fairTokenReserve;

    mapping(address => uint256) public baseTokenDeposit;
    address[] public baseTokenDepositAddress;

    address public fairTokenProvider;

    uint256 public depositedBaseToken;
    uint256 public depositedFairToken;

    bool public rasing_paused;

     /// @notice Possible remove status
    enum RmInstruction {
        RemoveBoth,
        RemoveBaseToken,
        RemoveFairToken
    }

    constructor() {
        // --------------- init token ---------------
        // init test token A
        // in demo, user can use test token A to subscribe token B
        ERC20WithFaucet _baseToken = new ERC20WithFaucet("TestBaseToken", "TBT");
        _baseToken.faucet();
        // init test token B and transfer some test token B to the provider
        // in demo, provider will use token B to raising fund
        fairTokenProvider = msg.sender;
        ERC20Mintable _fairToken = new ERC20Mintable("TestFairToken", "TFT");
        // unchecked {
        uint256 amount = 1000000 * (10 ** _fairToken.decimals()); // mint 100000 tokenB
        _fairToken.mint(msg.sender, amount);
        // }
        // after get token, provider and user both use `deposit` function to deposit token
        // --------------- init token ---------------
        baseToken = IERC20(address(_baseToken));
        fairToken = IERC20(address(_fairToken));
    }

    function mint(address to, uint256 amount) private {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) private {
        _burn(from, amount);
    }

    // Modifier to check token allowance
    modifier checkAllowance(uint256 baseTokenAmount, uint256 fairTokenAmount) {
        require(
            baseToken.allowance(msg.sender, address(this)) > baseTokenAmount &&
                fairToken.allowance(msg.sender, address(this)) > fairTokenAmount,
            "Not allowance token"
        );
        _;
    }

    function deposit(
        uint256 baseTokenAmount,
        uint256 fairTokenAmount
    ) external payable checkAllowance(baseTokenAmount, fairTokenAmount) {
        require(
            baseTokenAmount > 0 || fairTokenAmount > 0,
            "deposit: INSUFFICIENT_INPUT_AMOUNT"
        );
        require(rasing_paused == false, "deposit: raising time is over");

        if (baseTokenAmount > 0) {
            baseToken.transferFrom(msg.sender, address(this), baseTokenAmount);

            if (baseTokenDeposit[msg.sender] == 0) {
                baseTokenDepositAddress.push(address(msg.sender));
            }

            baseTokenDeposit[msg.sender] = baseTokenDeposit[msg.sender] + baseTokenAmount;

            depositedBaseToken = depositedBaseToken + baseTokenAmount;
        }
        if (fairTokenAmount > 0) {
            fairToken.transferFrom(msg.sender, address(this), fairTokenAmount);
            depositedFairToken = depositedFairToken + fairTokenAmount;
        }
        // emit Deposit(msg.sender, batchid, baseTokenAmount, fairTokenAmount);
    }

    // add liquidity, support add single side liquidity
    function addLiquidity(
        uint256 baseTokenAmount,
        uint256 fairTokenAmount
    ) external checkAllowance(baseTokenAmount, fairTokenAmount) {
        require(
            baseTokenAmount > 0 || fairTokenAmount > 0,
            "addLiquidity: INSUFFICIENT_INPUT_AMOUNT"
        );
        require(rasing_paused == true, "deposit: raising time has not over");

        uint256 lp_supply = totalSupply();
        require(lp_supply != 0, "pool has not initialized");

        uint256 amountLP;
        if (baseTokenAmount > 0) {
            baseToken.transferFrom(msg.sender, address(this), baseTokenAmount);
            amountLP +=
                (lp_supply * Math.sqrt((baseTokenAmount + baseTokenReserve) * baseTokenReserve)) /
                baseTokenReserve -
                lp_supply;
            lp_supply += amountLP;
            baseTokenReserve += baseTokenAmount;
        }
        if (fairTokenAmount > 0) {
            fairToken.transferFrom(msg.sender, address(this), fairTokenAmount);
            amountLP +=
                (lp_supply * Math.sqrt((fairTokenAmount + fairTokenReserve) * fairTokenReserve)) /
                fairTokenReserve -
                lp_supply;
            // lp_supply += amountLP; // do not used, can comment out
            fairTokenReserve += fairTokenAmount;
        }
        mint(msg.sender, amountLP);
    }

    // Modifier to check token allowance
    modifier checkLPAllowance(uint256 amountLPB) {
        require(
            allowance(msg.sender, address(this)) >= amountLPB,
            "Not allowance LP token"
        );
        _;
    }

    // remove liquidity
    function removeLiquidity(
        uint256 amountLP,
        RmInstruction remove
    ) external checkLPAllowance(amountLP) {
        require(amountLP > 0, "removeLiquidity: INSUFFICIENT_INPUT_AMOUNT");
        uint256 lp_supply = totalSupply();
        require(lp_supply > 0, "pool has not been initialized");
        burn(msg.sender, amountLP);
        uint256 _baseTokenReserve = baseTokenReserve;
        uint256 _fairTokenReserve = fairTokenReserve;

        if (remove == RmInstruction.RemoveBoth) {
            baseToken.transfer(msg.sender, (amountLP * _baseTokenReserve) / lp_supply);
            fairToken.transfer(msg.sender, (amountLP * _fairTokenReserve) / lp_supply);
        } else if (remove == RmInstruction.RemoveBaseToken) {
            uint256 amount = _baseTokenReserve -
                ((_baseTokenReserve *
                    ((lp_supply - amountLP) * (lp_supply - amountLP))) /
                    lp_supply /
                    lp_supply);
            baseToken.transfer(msg.sender, amount);
        } else if (remove == RmInstruction.RemoveFairToken) {
            uint256 amount = _fairTokenReserve -
                ((_fairTokenReserve *
                    ((lp_supply - amountLP) * (lp_supply - amountLP))) /
                    lp_supply /
                    lp_supply);
            fairToken.transfer(msg.sender, amount);
        }
    }

    function withdraw() external {
        require(
            fairTokenProvider == msg.sender,
            "only tokenB provider can withdraw"
        );
        require(rasing_paused == true, "fund rasing has not over");
        require(
            depositedBaseToken == 0,
            "only withdraw when the fund raising fails"
        );
        fairToken.transfer(msg.sender, depositedFairToken);
    }

    function _perform() internal {
        if (depositedBaseToken != 0) {
            uint256 lp_supply = totalSupply();
            require(lp_supply == 0, "pool has been initialized");
            baseTokenReserve = depositedBaseToken;
            fairTokenReserve = depositedFairToken;
            // init lp supply
            lp_supply = Math.sqrt(depositedBaseToken * depositedFairToken);

            // lp for fairTokenProvider
            mint(fairTokenProvider, lp_supply >> 1);
            console.log("mint lp supply %s to fair token provider", lp_supply / 2);

            // transfer LP to user who deposit tokenA
            uint256 _length = baseTokenDepositAddress.length;
            for (uint256 i = 0; i < _length; ) {
                address user_addr = baseTokenDepositAddress[i];
                uint256 deposit_amount = baseTokenDeposit[user_addr];
                uint256 lp_amount = ((deposit_amount * lp_supply) >> 1) /
                    baseTokenReserve;

                console.log(
                    "deposit_amount %s baseTokenReserve %s lp_amount %s",
                    deposit_amount,
                    baseTokenReserve,
                    lp_amount
                );
                // lp for baseToken deposit user
                mint(user_addr, lp_amount);
                console.log(
                    "mint lp amount %s to baseToken deposit user",
                    lp_amount
                );
                // cannot realistically overflow on human timescales
                unchecked {
                    ++i;
                }
            }
        }
    }

    function setRasingPaused() external {
        require(rasing_paused == false, "rasing time is over");
        rasing_paused = true;
        _perform();
    }
}
