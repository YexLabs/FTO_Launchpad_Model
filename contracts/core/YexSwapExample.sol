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
    IERC20 public baseToken;

    ///@notice The second token for exchange
    IERC20 public fairToken;

    ///@notice The reserve for baseToken
    uint256 baseTokenReserve;

    ///@notice The reserve for fairToken
    uint256 fairTokenReserve;

    /// @notice Possible remove status
    enum RmInstruction {
        RemoveBoth,
        RemoveBaseToken,
        RemoveFairToken
    }

    constructor(
        string memory name,
        string memory symbol,
        address _baseToken,
        address _fairToken
    ) ERC20(name, symbol) {
        // feeTo = msg.sender;
        ERC20WithFaucet baseToken_ = ERC20WithFaucet(_baseToken);
        baseToken_.faucet();
        ERC20WithFaucet fairToken_ = ERC20WithFaucet(_fairToken);
        fairToken_.faucet();

        baseToken = IERC20(_baseToken);
        fairToken = IERC20(_fairToken);

        _initLiquidity(
            baseToken.balanceOf(address(this)),
            fairToken.balanceOf(address(this))
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
            baseToken.allowance(msg.sender, address(this)) >= amountA,
            "Not allowance baseToken"
        );
        require(
            fairToken.allowance(msg.sender, address(this)) >= amountB,
            "Not allowance fairToken"
        );
        _;
    }

    //function to initialize the liquidity pool.
    function _initLiquidity(uint256 amountA, uint256 amountB) internal {
        require(
            amountA > 0 && amountB > 0,
            "addLiquidity: INSUFFICIENT_INPUT_AMOUNT"
        );
        uint256 lpSupply = totalSupply();
        require(lpSupply == 0, "pool has been initialized");
        baseTokenReserve = amountA;
        fairTokenReserve = amountB;
        console.log("pool %s init liquidity", name(), baseTokenReserve, fairTokenReserve);
        // mint to construtor
        mint(msg.sender, 10 ** 18);
    }

    //function to add the liquidity which also supports the functionality to add single side liquidity
    function addLiquidity(
        uint256 baseTokenAmount,
        uint256 amountB
    ) external checkAllowance(baseTokenAmount, amountB) {
        require(
            baseTokenAmount > 0 || amountB > 0,
            "addLiquidity: INSUFFICIENT_INPUT_AMOUNT"
        );
        uint256 lpSupply = totalSupply();
        require(lpSupply > 0, "pool has not been initialized");

        uint256 amountLP = 0;

        if (baseTokenAmount > 0) {
            uint256 _baseTokenReserve = baseTokenReserve;
            baseToken.transferFrom(msg.sender, address(this), baseTokenAmount);
            amountLP +=
                (lpSupply * Math.sqrt((baseTokenAmount + _baseTokenReserve) * _baseTokenReserve)) /
                _baseTokenReserve -
                lpSupply;
            baseTokenReserve += baseTokenAmount;
        }
        if (amountB > 0) {
            uint256 _fairTokenReserve = fairTokenReserve;
            fairToken.transferFrom(msg.sender, address(this), amountB);
            amountLP +=
                (lpSupply * Math.sqrt((amountB + _fairTokenReserve) * _fairTokenReserve)) /
                _fairTokenReserve -
                lpSupply;
            fairTokenReserve += amountB;
        }
        
        lpSupply += amountLP;
        
        console.log(
            "pool %s add liquidity current reserves %s %s",
            name(),
            baseTokenReserve,
            fairTokenReserve
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
        uint256 lpSupply = totalSupply();
        console.log(
            "remove liquidity,current lp %s remove lp %s ",
            lpSupply,
            amountLP
        );
        require(lpSupply > 0, "pool has not been initialized");
        //Validate: if this is correct meaning
        require(
            amountLP < lpSupply,
            "removeLiquidity: EXCEEDING_REMOVE_LIMIT"
        );
        burn(msg.sender, amountLP);
        uint256 _baseTokenReserve = baseTokenReserve;
        uint256 _fairTokenReserve = fairTokenReserve;
        //The case to remove both token A and token B
        if (remove == RmInstruction.RemoveBoth) {
            baseToken.transfer(msg.sender, (amountLP * _baseTokenReserve) / lpSupply);
            fairToken.transfer(msg.sender, (amountLP * _fairTokenReserve) / lpSupply);
        }
        //The case to just remove the token A
        else if (remove == RmInstruction.RemoveBaseToken) {
            uint256 amount = _baseTokenReserve -
                ((_baseTokenReserve *
                    ((lpSupply - amountLP) * (lpSupply - amountLP))) /
                    lpSupply /
                    lpSupply);
            baseToken.transfer(msg.sender, amount);
        } else if (remove == RmInstruction.RemoveFairToken) {
            uint256 amount = _fairTokenReserve -
                ((_fairTokenReserve *
                    ((lpSupply - amountLP) * (lpSupply - amountLP))) /
                    lpSupply /
                    lpSupply);
            fairToken.transfer(msg.sender, amount);
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
        uint256 kValue = baseTokenReserve * fairTokenReserve;
        if (amountA > 0) {
            uint256 rb = fairTokenReserve;
            baseTokenReserve += amountA;
            fairTokenReserve = kValue / baseTokenReserve;

            amountBOut = rb - fairTokenReserve;
        } else {
            uint256 ra = baseTokenReserve;
            fairTokenReserve += amountB;
            baseTokenReserve = kValue / fairTokenReserve;

            amountAOut = ra - baseTokenReserve;
        }
    }

    /// @notice : avoid the use of the state variable for calculation for gas-saving.
    function getReserves()
        public
        view
        override
        returns (uint256 _reserve0, uint256 _reserve1)
    {
        _reserve0 = baseTokenReserve;
        _reserve1 = fairTokenReserve;
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
        mapping(address => uint256) depositedBaseToken;
        /// @notice mapping for fairToken address to amount
        mapping(address => uint256) depositedFairToken;
        /// @notice all the addresses stored the base token
        address[] baseTokenDepositAddress;
        /// @notice all the addresses stored the fair token
        address[] fairTokenDepositAddress;
        /// @notice every transaction volume for each batch of base token
        uint256 batchBaseToken;
        /// @notice every transaction volume for each batch of fair token
        uint256 batchFairToken;
        /// @notice record the startTime for the batch
        uint256 startTime;
    }

    struct PoolInfo {
        uint256 minBaseTokenReserve;
        uint256 minFairTokenReserve;
        IYexSwapPool minPool;
        uint256 maxBaseTokenReserve;
        uint256 maxFairTokenReserve;
        IYexSwapPool maxPool;
    }

    mapping(uint256 => TokenInfo) batchInfo;

    constructor(
        address _baseToken,
        address _fairToken
    ) YexSwapPool("Pool1", "P1", _baseToken, _fairToken) {
        // create inner pool to simulate a dex
        YexSwapPool pool2_ = new YexSwapPool("Pool2", "P2", _baseToken, _fairToken);

        pool1 = IYexSwapPool(address(this));
        pool2 = IYexSwapPool(address(pool2_));

        baseToken = IERC20(_baseToken);
        fairToken = IERC20(_fairToken);
    }

    function deposit(
        uint256 baseTokenAmount,
        uint256 fairTokenAmount
    ) external checkAllowance(baseTokenAmount, fairTokenAmount) {
        require(
            baseTokenAmount > 0 || fairTokenAmount > 0,
            "deposit: INSUFFICIENT_INPUT_AMOUNT"
        );

        uint256 currentBatch = batchid;

        // setup new batch start time
        if (batchInfo[currentBatch].startTime == 0) {
            batchInfo[currentBatch].startTime = block.timestamp;
        }

        if (baseTokenAmount > 0) {
            baseToken.transferFrom(msg.sender, address(this), baseTokenAmount);

            // first deposit, add into deposit array
            if (batchInfo[currentBatch].depositedBaseToken[msg.sender] == 0) {
                batchInfo[currentBatch].baseTokenDepositAddress.push(
                    address(msg.sender)
                );
            }

            batchInfo[currentBatch].depositedBaseToken[msg.sender] =
                batchInfo[currentBatch].depositedBaseToken[msg.sender] +
                baseTokenAmount;

            batchInfo[currentBatch].batchBaseToken =
                batchInfo[currentBatch].batchBaseToken +
                baseTokenAmount;
        }
        if (fairTokenAmount > 0) {
            fairToken.transferFrom(msg.sender, address(this), fairTokenAmount);

            // first deposit, add into deposit array
            if (batchInfo[currentBatch].depositedFairToken[msg.sender] == 0) {
                batchInfo[currentBatch].fairTokenDepositAddress.push(
                    address(msg.sender)
                );
            }

            batchInfo[currentBatch].depositedFairToken[msg.sender] =
                batchInfo[currentBatch].depositedFairToken[msg.sender] +
                fairTokenAmount;

            batchInfo[currentBatch].batchFairToken =
                batchInfo[currentBatch].batchFairToken +
                fairTokenAmount;
        }
        // emit Deposit(msg.sender, batchid, baseTokenAmount, fairTokenAmount);
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
            (block.timestamp - batchInfo[batchid].startTime) > 10 &&
            (batchInfo[batchid].batchBaseToken > 0 ||
                batchInfo[batchid].batchFairToken > 0);
        performData = "";
    }

    // 1. calculate minPool and maxPool from pool list
    // 2. calculate delta amount to swap with minPool or maxPool
    // 3. transfer token to users
    function performUpkeep(bytes calldata /* performData */) external override {
        TokenInfo storage currentTokenInfo = batchInfo[batchid];
        require(
            (block.timestamp - currentTokenInfo.startTime) > 10 &&
                (currentTokenInfo.batchBaseToken > 0 ||
                    currentTokenInfo.batchFairToken > 0),
            "not need to perform"
        );

        // setup a new batch
        // batch_startTime[currentBatch] = block.timestamp;
        //this is the same look up we are having with require statement. why do we need to duplicate?
        uint256 baseTokenBalance = currentTokenInfo.batchBaseToken;
        uint256 fairTokenBalance = currentTokenInfo.batchFairToken;
        uint256 baseTokenBalance_ = baseTokenBalance;
        uint256 fairTokenBalance_ = fairTokenBalance;

        console.log(
            "before auction, baseTokenBalance:%s fairTokenBalance:%s",
            baseTokenBalance_,
            fairTokenBalance_
        );

        PoolInfo memory poolInfo = _getCompareReserves();

        // 1. auction price is greater than maximum price
        if (
            ((fairTokenBalance * poolInfo.maxBaseTokenReserve)) >
            (poolInfo.maxFairTokenReserve * baseTokenBalance)
        ) {
            uint256 delta;
            delta = (fairTokenBalance -
                (baseTokenBalance * poolInfo.minFairTokenReserve) /
                poolInfo.minBaseTokenReserve);
            fairTokenBalance_ -= delta;
            // swap using the pool with the minimum price
            if (address(poolInfo.minPool) == address(this)) {
                (delta, ) = _swap(0, delta);
            } else {
                (delta, ) = poolInfo.minPool.swap(0, delta);
            }
            baseTokenBalance_ += delta;
        } else if (
            ((fairTokenBalance * poolInfo.minBaseTokenReserve)) <
            (poolInfo.minFairTokenReserve * baseTokenBalance)
        ) {
            //2. auction price is less than minimum price
            uint256 delta;
            delta = (baseTokenBalance -
                (fairTokenBalance * poolInfo.maxBaseTokenReserve) /
                poolInfo.maxFairTokenReserve);
            baseTokenBalance_ -= delta;
            // swap using the pool with the maximum price
            if (address(poolInfo.maxPool) == address(this)) {
                (, delta) = _swap(delta, 0);
            } else {
                (, delta) = poolInfo.maxPool.swap(delta, 0);
            }
            fairTokenBalance_ += delta;
        }

        console.log(
            "after auction, baseTokenBalance:%s fairTokenBalance:%s",
            baseTokenBalance_,
            fairTokenBalance_
        );

        uint256 len = currentTokenInfo.fairTokenDepositAddress.length;
        // transfer tokenA to user who deposit fairToken
        for (uint256 i = 0; i < len; ) {
            address userAddr = currentTokenInfo.fairTokenDepositAddress[i];
            uint256 depositAmount = currentTokenInfo.depositedFairToken[
                userAddr
            ];
            uint256 withdrawAmount = (depositAmount * baseTokenBalance_) / fairTokenBalance;
            console.log(
                "transfer baseToken %s to user who deposit fairToken",
                withdrawAmount
            );
            baseToken.transfer(userAddr, withdrawAmount);

            // delete batchInfo's mapping
            delete currentTokenInfo.depositedFairToken[userAddr];

            // cannot realistically overflow on human timescales
            unchecked {
                ++i;
            }
        }

        // transfer fairToken to user who deposit baseToken
        len = currentTokenInfo.baseTokenDepositAddress.length;
        for (uint256 i = 0; i < len; ) {
            address userAddr = currentTokenInfo.baseTokenDepositAddress[i];
            uint256 depositAmount = currentTokenInfo.depositedBaseToken[
                userAddr
            ];
            uint256 withdrawAmount = (depositAmount * fairTokenBalance_) / baseTokenBalance;
            console.log(
                "transfer fiarToken %s to user who deposit baseToken",
                withdrawAmount
            );
            fairToken.transfer(userAddr, withdrawAmount);

            // delete batchInfo's mapping
            delete currentTokenInfo.depositedBaseToken[userAddr];

            // cannot realistically overflow on human timescales
            unchecked {
                ++i;
            }
        }
        // console.log("before %s", batchInfo[currentBatch].startTime);

        // delete batchInfo
        delete (batchInfo[batchid]);

        // console.log("after %s", batchInfo[currentBatch].startTime);
        batchid += 1;
    }

    /// @notice need support more pools
    function _getCompareReserves() internal view returns (PoolInfo memory) {
        // pool reserve
        (uint256 pool1BaseTokenReserve, uint256 pool1FairTokenReserve) = getReserves();
        (uint256 pool2BaseTokenReserve, uint256 pool2FairTokenReserve) = pool2.getReserves();

        // compare B/A
        if (
            (pool2BaseTokenReserve * pool1FairTokenReserve) >
            (pool2FairTokenReserve * pool1BaseTokenReserve)
        ) {
            return
                PoolInfo(
                    pool2BaseTokenReserve,
                    pool2FairTokenReserve,
                    pool2,
                    pool1BaseTokenReserve,
                    pool1FairTokenReserve,
                    pool1
                );
        } else {
            return
                PoolInfo(
                    pool1BaseTokenReserve,
                    pool1FairTokenReserve,
                    pool1,
                    pool2BaseTokenReserve,
                    pool2FairTokenReserve,
                    pool2
                );
        }
    }

    function getExpectedAmountOut(
        address token,
        uint256 amountIn
    ) external view returns (uint256) {
        uint256 baseTokenBalance = batchInfo[batchid].batchBaseToken;
        uint256 fairTokenBalance = batchInfo[batchid].batchFairToken;
        uint256 fairTokenBalanceBeforeSwap;
        uint256 baseTokenBalanceBeforeSwap;
        if (token == address(baseToken)) {
            baseTokenBalanceBeforeSwap = baseTokenBalance + amountIn;
            fairTokenBalanceBeforeSwap = fairTokenBalance;
        } else {
            fairTokenBalanceBeforeSwap = fairTokenBalance + amountIn;
            baseTokenBalanceBeforeSwap = baseTokenBalance;
        }
        uint256 baseTokenBalance_ = baseTokenBalanceBeforeSwap;
        uint256 fairTokenBalance_ = fairTokenBalanceBeforeSwap;

        console.log(
            "before swap, baseTokenBalance:%s fairTokenBalance:%s",
            baseTokenBalanceBeforeSwap,
            fairTokenBalanceBeforeSwap
        );

        PoolInfo memory poolInfo = _getCompareReserves();

        // 1. The case for auction > max
        if (
            ((fairTokenBalanceBeforeSwap * poolInfo.maxBaseTokenReserve)) >
            (poolInfo.maxFairTokenReserve * baseTokenBalanceBeforeSwap)
        ) {
            // part of balance just swap
            uint256 delta;
            delta = (fairTokenBalanceBeforeSwap -
                (baseTokenBalanceBeforeSwap * poolInfo.minFairTokenReserve) /
                poolInfo.minBaseTokenReserve);
            fairTokenBalance_ -= delta;
            (delta, ) = getOptionalAmountOut(
                0,
                delta,
                poolInfo.minBaseTokenReserve,
                poolInfo.minFairTokenReserve
            );
            baseTokenBalance_ += delta;
        } else if (
            ((fairTokenBalanceBeforeSwap * poolInfo.minBaseTokenReserve)) <
            (poolInfo.minFairTokenReserve * baseTokenBalanceBeforeSwap)
        ) {
            uint256 delta;
            delta = (baseTokenBalanceBeforeSwap -
                (fairTokenBalanceBeforeSwap * poolInfo.maxBaseTokenReserve) /
                poolInfo.maxFairTokenReserve);
            baseTokenBalance_ -= delta;
            (, delta) = getOptionalAmountOut(
                delta,
                0,
                poolInfo.maxBaseTokenReserve,
                poolInfo.maxFairTokenReserve
            );
            fairTokenBalance_ += delta;
        }

        console.log(
            "expected auction, baseTokenBalance:%s fairTokenBalance:%s",
            baseTokenBalance_,
            fairTokenBalance_
        );
        if (token == address(baseToken)) {
            return (amountIn * fairTokenBalance_) / baseTokenBalanceBeforeSwap;
        } else {
            return (amountIn * baseTokenBalance_) / fairTokenBalanceBeforeSwap;
        }
    }

    function getOptionalAmountOut(
        uint256 baseTokenAmount,
        uint256 fairTokenAmount,
        uint256 baseTokenReserve,
        uint256 fairTokenReserve
    ) internal pure returns (uint256 baseTokenOut, uint256 fiarTokenOut) {
        uint256 kValue = baseTokenReserve * fairTokenReserve;
        if (baseTokenAmount > 0) {
            uint256 rb = fairTokenReserve;
            baseTokenReserve += baseTokenAmount;
            fairTokenReserve = kValue / baseTokenReserve;
            fiarTokenOut = rb - fairTokenReserve;
        } else {
            uint256 ra = baseTokenReserve;
            fairTokenReserve += fairTokenAmount;
            baseTokenReserve = kValue / fairTokenReserve;
            baseTokenOut = ra - baseTokenReserve;
        }
    }
}
