// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/ERC20.sol";
import "../libraries/AutomationCompatibleInterface.sol";
import "../libraries/Math.sol";
import "../interfaces/IYexSwapPool.sol";
// import "hardhat/console.sol";
import "../libraries/Console.sol";

/**
 * @dev the contract to request the faucet.
 *
 */

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

/**
 * @dev the super contract of the YexSwapExample contract
 including the few wrapped helper functions to for supporting the operation of the YexSwapExample contract
 * this contract support add/remove single liquidity
 */

contract YexSwapPool is ERC20, IYexSwapPool {
    // Constant K value pool
    ///@notice The first token for exchange
    IERC20 public tokenA;

    ///@notice The second token for exchange
    IERC20 public tokenB;

    ///@notice The reserve for tokenA
    uint256 reserveA;

    ///@notice The reserve for tokenB
    uint256 reserveB;

    /// @notice Possible remove status
    enum RmInstruction {
        RemoveBoth,
        RemoveTokenA,
        RemoveTokenB
    }

    constructor(
        string memory name,
        string memory symbol,
        address _tokenA,
        address _tokenB
    ) ERC20(name, symbol) {
        // feeTo = msg.sender;
        ERC20WithFaucet tokenA_ = ERC20WithFaucet(_tokenA);
        tokenA_.faucet();
        ERC20WithFaucet tokenB_ = ERC20WithFaucet(_tokenB);
        tokenB_.faucet();

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);

        _initLiquidity(
            tokenA.balanceOf(address(this)),
            tokenB.balanceOf(address(this))
        );
    }

    function mint(address to, uint256 amount) private {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) private {
        _burn(from, amount);
    }

    // Modifier to check token allowance
    modifier checkAllowance(uint256 amountA, uint256 amountB) {
        require(
            tokenA.allowance(msg.sender, address(this)) >= amountA,
            "Not allowance tokenA"
        );
        require(
            tokenB.allowance(msg.sender, address(this)) >= amountB,
            "Not allowance tokenB"
        );
        _;
    }

    //function to initialize the liquidity pool.
    function _initLiquidity(uint256 amountA, uint256 amountB) internal {
        require(
            amountA > 0 && amountB > 0,
            "addLiquidity: INSUFFICIENT_INPUT_AMOUNT"
        );
        uint256 lp_supply = totalSupply();
        require(lp_supply == 0, "pool has been initialized");
        reserveA = amountA;
        reserveB = amountB;
        console.log("pool %s init liquidity", name(), reserveA, reserveB);
        // mint to construtor
        mint(msg.sender, 10 ** 18);
    }

    //function to add the liquidity which also supports the functionality to add single side liquidity
    function addLiquidity(
        uint256 amountA,
        uint256 amountB
    ) external checkAllowance(amountA, amountB) {
        require(
            amountA > 0 || amountB > 0,
            "addLiquidity: INSUFFICIENT_INPUT_AMOUNT"
        );
        uint256 lp_supply = totalSupply();
        require(lp_supply > 0, "pool has not been initialized");

        uint256 amountLP = 0;

        if (amountA > 0) {
            uint256 _reserveA = reserveA;
            tokenA.transferFrom(msg.sender, address(this), amountA);
            amountLP +=
                (lp_supply * Math.sqrt((amountA + _reserveA) * _reserveA)) /
                _reserveA -
                lp_supply;
            reserveA += amountA;
        }
        if (amountB > 0) {
            uint256 _reserveB = reserveB;
            tokenB.transferFrom(msg.sender, address(this), amountB);
            amountLP +=
                (lp_supply * Math.sqrt((amountB + _reserveB) * _reserveB)) /
                _reserveB -
                lp_supply;
            reserveB += amountB;
        }
        
        lp_supply += amountLP;
        
        console.log(
            "pool %s add liquidity current reserves %s %s",
            name(),
            reserveA,
            reserveB
        );
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

    //function to remove the liquidity
    function removeLiquidity(
        uint256 amountLP,
        RmInstruction remove // checkLPAllowance(amountLP)
    ) external {
        require(amountLP > 0, "removeLiquidity: INSUFFICIENT_INPUT_AMOUNT");
        uint256 lp_supply = totalSupply();
        console.log(
            "remove liquidity,current lp %s remove lp %s ",
            lp_supply,
            amountLP
        );
        require(lp_supply > 0, "pool has not been initialized");
        //Validate: if this is correct meaning
        require(
            amountLP < lp_supply,
            "removeLiquidity: EXCEEDING_REMOVE_LIMIT"
        );
        burn(msg.sender, amountLP);
        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;
        //The case to remove both token A and token B
        if (remove == RmInstruction.RemoveBoth) {
            tokenA.transfer(msg.sender, (amountLP * _reserveA) / lp_supply);
            tokenB.transfer(msg.sender, (amountLP * _reserveB) / lp_supply);
        }
        //The case to just remove the token A
        else if (remove == RmInstruction.RemoveTokenA) {
            uint256 amount = _reserveA -
                ((_reserveA *
                    ((lp_supply - amountLP) * (lp_supply - amountLP))) /
                    lp_supply /
                    lp_supply);
            tokenA.transfer(msg.sender, amount);
        } else if (remove == RmInstruction.RemoveTokenB) {
            uint256 amount = _reserveB -
                ((_reserveB *
                    ((lp_supply - amountLP) * (lp_supply - amountLP))) /
                    lp_supply /
                    lp_supply);
            tokenB.transfer(msg.sender, amount);
        }
    }

    function swap(
        uint256 amountA,
        uint256 amountB
    ) external override returns (uint256 amountAOut, uint256 amountBOut) {
        (amountAOut, amountBOut) = _swap(amountA, amountB);
    }

    function _swap(
        uint256 amountA,
        uint256 amountB
    ) internal returns (uint256 amountAOut, uint256 amountBOut) {
        uint256 kValue = reserveA * reserveB;
        if (amountA > 0) {
            uint256 rb = reserveB;
            reserveA += amountA;
            reserveB = kValue / reserveA;

            amountBOut = rb - reserveB;
        } else {
            uint256 ra = reserveA;
            reserveB += amountB;
            reserveA = kValue / reserveB;

            amountAOut = ra - reserveA;
        }
    }

    /// @notice : avoid the use of the state variable for calculation for gas-saving.
    function getReserves()
        public
        view
        override
        returns (uint256 _reserve0, uint256 _reserve1)
    {
        _reserve0 = reserveA;
        _reserve1 = reserveB;
    }
}

/**
 * @dev the contract aggregate the transactions in batch to against sandwich attack.
    added chainlink automation features support to enhance the user experience
 */

contract YexSwapExample is YexSwapPool, AutomationCompatibleInterface {
    ///@notice first pool being used to balance the trading price to prevent the sandwich attack
    IYexSwapPool public pool1;

    ///@notice fsecond pool being used to balance the trading price to prevent the sandwich attack
    IYexSwapPool public pool2;
    ///@notice we bundle the auction in batch, this id to record batch auction
    uint256 public batchid;

    struct TokenInfo {
        /// @notice mapping for tokenA address to amount
        mapping(address => uint256) deposited_tokenA;
        /// @notice mapping for tokenB address to amount
        mapping(address => uint256) deposited_tokenB;
        /// @notice all the addresses stored the token A
        address[] tokenA_deposit_address;
        /// @notice all the addresses stored the token A
        address[] tokenB_deposit_address;
        /// @notice every transaction volume for each batch of token A
        uint256 batch_tokenA;
        /// @notice every transaction volume for each batch of token B
        uint256 batch_tokenB;
        /// @notice record the start_time for the batch
        uint256 start_time;
    }

    struct PoolInfo {
        uint256 min_reserveA;
        uint256 min_reserveB;
        IYexSwapPool min_pool;
        uint256 max_reserveA;
        uint256 max_reserveB;
        IYexSwapPool max_pool;
    }

    mapping(uint256 => TokenInfo) batch_info;

    constructor(
        address _tokenA,
        address _tokenB
    ) YexSwapPool("Pool1", "P1", _tokenA, _tokenB) {
        // create inner pool to simulate a dex
        YexSwapPool pool2_ = new YexSwapPool("Pool2", "P2", _tokenA, _tokenB);

        pool1 = IYexSwapPool(address(this));
        pool2 = IYexSwapPool(address(pool2_));

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function deposit(
        uint256 amountA,
        uint256 amountB
    ) external checkAllowance(amountA, amountB) {
        require(
            amountA > 0 || amountB > 0,
            "deposit: INSUFFICIENT_INPUT_AMOUNT"
        );

        uint256 current_batch = batchid;

        // setup new batch start time
        if (batch_info[current_batch].start_time == 0) {
            batch_info[current_batch].start_time = block.timestamp;
        }

        if (amountA > 0) {
            tokenA.transferFrom(msg.sender, address(this), amountA);

            // first deposit, add into deposit array
            if (batch_info[current_batch].deposited_tokenA[msg.sender] == 0) {
                batch_info[current_batch].tokenA_deposit_address.push(
                    address(msg.sender)
                );
            }

            batch_info[current_batch].deposited_tokenA[msg.sender] =
                batch_info[current_batch].deposited_tokenA[msg.sender] +
                amountA;

            batch_info[current_batch].batch_tokenA =
                batch_info[current_batch].batch_tokenA +
                amountA;
        }
        if (amountB > 0) {
            tokenB.transferFrom(msg.sender, address(this), amountB);

            // first deposit, add into deposit array
            if (batch_info[current_batch].deposited_tokenB[msg.sender] == 0) {
                batch_info[current_batch].tokenB_deposit_address.push(
                    address(msg.sender)
                );
            }

            batch_info[current_batch].deposited_tokenB[msg.sender] =
                batch_info[current_batch].deposited_tokenB[msg.sender] +
                amountB;

            batch_info[current_batch].batch_tokenB =
                batch_info[current_batch].batch_tokenB +
                amountB;
        }
        // emit Deposit(msg.sender, batchid, amountA, amountB);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded =
            (block.timestamp - batch_info[batchid].start_time) > 10 &&
            (batch_info[batchid].batch_tokenA > 0 ||
                batch_info[batchid].batch_tokenB > 0);
        performData = "";
    }

    // 1. calculate min_pool and max_pool from pool list
    // 2. calculate delta amount to swap with min_pool or max_pool
    // 3. transfer token to users
    function performUpkeep(bytes calldata /* performData */) external override {
        TokenInfo storage currentTokenInfo = batch_info[batchid];
        require(
            (block.timestamp - currentTokenInfo.start_time) > 10 &&
                (currentTokenInfo.batch_tokenA > 0 ||
                    currentTokenInfo.batch_tokenB > 0),
            "not need to perform"
        );

        // setup a new batch
        // batch_start_time[currentBatch] = block.timestamp;
        //this is the same look up we are having with require statement. why do we need to duplicate?
        uint256 balanceA = currentTokenInfo.batch_tokenA;
        uint256 balanceB = currentTokenInfo.batch_tokenB;
        uint256 balanceA_ = balanceA;
        uint256 balanceB_ = balanceB;

        console.log(
            "before auction, balanceA:%s balanceB:%s",
            balanceA_,
            balanceB_
        );

        PoolInfo memory poolInfo = _getCompareReserves();

        // 1. auction price is greater than maximum price
        if (
            ((balanceB * poolInfo.max_reserveA)) >
            (poolInfo.max_reserveB * balanceA)
        ) {
            uint256 delta;
            delta = (balanceB -
                (balanceA * poolInfo.min_reserveB) /
                poolInfo.min_reserveA);
            balanceB_ -= delta;
            // swap using the pool with the minimum price
            if (address(poolInfo.min_pool) == address(this)) {
                (delta, ) = _swap(0, delta);
            } else {
                (delta, ) = poolInfo.min_pool.swap(0, delta);
            }
            balanceA_ += delta;
        } else if (
            ((balanceB * poolInfo.min_reserveA)) <
            (poolInfo.min_reserveB * balanceA)
        ) {
            //2. auction price is less than minimum price
            uint256 delta;
            delta = (balanceA -
                (balanceB * poolInfo.max_reserveA) /
                poolInfo.max_reserveB);
            balanceA_ -= delta;
            // swap using the pool with the maximum price
            if (address(poolInfo.max_pool) == address(this)) {
                (, delta) = _swap(delta, 0);
            } else {
                (, delta) = poolInfo.max_pool.swap(delta, 0);
            }
            balanceB_ += delta;
        }

        console.log(
            "after auction, balanceA:%s balanceB:%s",
            balanceA_,
            balanceB_
        );

        uint256 len = currentTokenInfo.tokenB_deposit_address.length;
        // transfer tokenA to user who deposit tokenB
        for (uint256 i = 0; i < len; ) {
            address user_addr = currentTokenInfo.tokenB_deposit_address[i];
            uint256 deposit_amount = currentTokenInfo.deposited_tokenB[
                user_addr
            ];
            uint256 withdraw_amount = (deposit_amount * balanceA_) / balanceB;
            console.log(
                "transfer tokenA %s to user who deposit tokenB",
                withdraw_amount
            );
            tokenA.transfer(user_addr, withdraw_amount);

            // delete batchInfo's mapping
            delete currentTokenInfo.deposited_tokenB[user_addr];

            // cannot realistically overflow on human timescales
            unchecked {
                ++i;
            }
        }

        // transfer tokenB to user who deposit tokenA
        len = currentTokenInfo.tokenA_deposit_address.length;
        for (uint256 i = 0; i < len; ) {
            address user_addr = currentTokenInfo.tokenA_deposit_address[i];
            uint256 deposit_amount = currentTokenInfo.deposited_tokenA[
                user_addr
            ];
            uint256 withdraw_amount = (deposit_amount * balanceB_) / balanceA;
            console.log(
                "transfer tokenB %s to user who deposit tokenA",
                withdraw_amount
            );
            tokenB.transfer(user_addr, withdraw_amount);

            // delete batchInfo's mapping
            delete currentTokenInfo.deposited_tokenA[user_addr];

            // cannot realistically overflow on human timescales
            unchecked {
                ++i;
            }
        }
        // console.log("before %s", batch_info[currentBatch].start_time);

        // delete batchInfo
        delete (batch_info[batchid]);

        // console.log("after %s", batch_info[currentBatch].start_time);
        batchid += 1;
    }

    /// @notice need support more pools
    function _getCompareReserves() internal view returns (PoolInfo memory) {
        // pool reserve
        (uint256 pool1_reserveA, uint256 pool1_reserveB) = getReserves();
        (uint256 pool2_reserveA, uint256 pool2_reserveB) = pool2.getReserves();

        // compare B/A
        if (
            (pool2_reserveA * pool1_reserveB) >
            (pool2_reserveB * pool1_reserveA)
        ) {
            return
                PoolInfo(
                    pool2_reserveA,
                    pool2_reserveB,
                    pool2,
                    pool1_reserveA,
                    pool1_reserveB,
                    pool1
                );
        } else {
            return
                PoolInfo(
                    pool1_reserveA,
                    pool1_reserveB,
                    pool1,
                    pool2_reserveA,
                    pool2_reserveB,
                    pool2
                );
        }
    }

    function getExpectedAmountOut(
        address token,
        uint256 amountIn
    ) external view returns (uint256) {
        uint256 balanceA = batch_info[batchid].batch_tokenA;
        uint256 balanceB = batch_info[batchid].batch_tokenB;
        uint256 balanceB_before_swap;
        uint256 balanceA_before_swap;
        if (token == address(tokenA)) {
            balanceA_before_swap = balanceA + amountIn;
            balanceB_before_swap = balanceB;
        } else {
            balanceB_before_swap = balanceB + amountIn;
            balanceA_before_swap = balanceA;
        }
        uint256 balanceA_ = balanceA_before_swap;
        uint256 balanceB_ = balanceB_before_swap;

        console.log(
            "before swap, balanceA:%s balanceB:%s",
            balanceA_before_swap,
            balanceB_before_swap
        );

        PoolInfo memory poolInfo = _getCompareReserves();

        // 1. The case for auction > max
        if (
            ((balanceB_before_swap * poolInfo.max_reserveA)) >
            (poolInfo.max_reserveB * balanceA_before_swap)
        ) {
            // part of balance just swap
            uint256 delta;
            delta = (balanceB_before_swap -
                (balanceA_before_swap * poolInfo.min_reserveB) /
                poolInfo.min_reserveA);
            balanceB_ -= delta;
            (delta, ) = getOptionalAmountOut(
                0,
                delta,
                poolInfo.min_reserveA,
                poolInfo.min_reserveB
            );
            balanceA_ += delta;
        } else if (
            ((balanceB_before_swap * poolInfo.min_reserveA)) <
            (poolInfo.min_reserveB * balanceA_before_swap)
        ) {
            uint256 delta;
            delta = (balanceA_before_swap -
                (balanceB_before_swap * poolInfo.max_reserveA) /
                poolInfo.max_reserveB);
            balanceA_ -= delta;
            (, delta) = getOptionalAmountOut(
                delta,
                0,
                poolInfo.max_reserveA,
                poolInfo.max_reserveB
            );
            balanceB_ += delta;
        }

        console.log(
            "expected auction, balanceA:%s balanceB:%s",
            balanceA_,
            balanceB_
        );
        if (token == address(tokenA)) {
            return (amountIn * balanceB_) / balanceA_before_swap;
        } else {
            return (amountIn * balanceA_) / balanceB_before_swap;
        }
    }

    function getOptionalAmountOut(
        uint256 amountA,
        uint256 amountB,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountAOut, uint256 amountBOut) {
        uint256 kValue = reserveA * reserveB;
        if (amountA > 0) {
            uint256 rb = reserveB;
            reserveA += amountA;
            reserveB = kValue / reserveA;
            amountBOut = rb - reserveB;
        } else {
            uint256 ra = reserveA;
            reserveB += amountB;
            reserveA = kValue / reserveB;
            amountAOut = ra - reserveA;
        }
    }
}
