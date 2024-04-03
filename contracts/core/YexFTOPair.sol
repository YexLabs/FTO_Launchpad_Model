// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/ERC20.sol";
import "../libraries/Math.sol";
import "../libraries/Ownable.sol";
import "../libraries/Console.sol";
import "../interfaces/IYexFTOPair.sol";
import "../interfaces/IYexFTOFactory.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../libraries/TransferHelper.sol";

contract YexFTOPair is IYexFTOPair, ERC20("YexFTOPair", "FTOLP") {
    address public tokenA; // tokenA is used to subscribe tokenB
    address public tokenB; // tokenB is the issuer

    address public tokenBProvider;

    uint256 public depositedTokenA;
    uint256 public depositedTokenB;

    address public factory;

    uint256 public startTime = block.timestamp;
    uint256 public endTime;

    address public otherPool;
    uint256 public poolLP;
    uint256 public reserveA;

    Status public FTOState = Status.Processing;

    mapping(address => uint256) public tokenADeposit;
    mapping(address => uint256) public claimedLp;

    address[] public tokenADepositAddress;

    error InvalidAmount();
    error InvalidUpdate();

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "YexFTO: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(
        address _tokenA,
        address _tokenB,
        address _tokenBProvider,
        address _otherPool,
        uint256 rasingCycle
    ) external {
        require(msg.sender == factory, "YexFTOPair: FORBIDDEN"); // sufficient check
        tokenA = _tokenA;
        tokenB = _tokenB;
        tokenBProvider = _tokenBProvider;
        endTime = block.timestamp + rasingCycle;
        otherPool = _otherPool;
    }

    function depositTokenB(
        address depositer,
        uint256 amount
    ) external override {
        require(block.timestamp < endTime, "deposit: raising time is over");
        require(depositer == tokenBProvider, "only Project owner can deposit");
        if (amount == 0) {
            revert InvalidAmount();
        }
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));
        if (balanceB != amount + depositedTokenB) {
            revert InvalidUpdate();
        }
        depositedTokenB = depositedTokenB + amount;
        emit Deposit(depositer, amount);
    }

    function depositTokenA(
        address depositer,
        uint256 amount
    ) external override {
        require(block.timestamp < endTime, "deposit: raising time is over");
        require(
            depositer != tokenBProvider,
            "Project owner are not allowed to deposit with their launch"
        );
        if (amount == 0) {
            revert InvalidAmount();
        }
        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        if (balanceA != amount + depositedTokenA) {
            revert InvalidUpdate();
        }

        if (tokenADeposit[depositer] == 0) {
            tokenADepositAddress.push(depositer);
        }

        tokenADeposit[depositer] = tokenADeposit[depositer] + amount;
        depositedTokenA = depositedTokenA + amount;

        // update participations
        IYexFTOFactory(factory).addEvent(depositer, address(this));

        emit Deposit(depositer, amount);
    }

    function withdraw(address withdrawer) external override lock {
        require(FTOState == Status.Failed, "fund rasing not failed.");
        require(tokenBProvider == withdrawer, "only provider can withdraw");
        IERC20(tokenB).transfer(withdrawer, depositedTokenB);
        emit Withdraw(withdrawer, depositedTokenB);
    }

    function claimLP(address claimer) external lock {
        require(FTOState == Status.Success, "fund rasing not success.");
        require(
            tokenBProvider == claimer || tokenADeposit[claimer] != 0,
            "only tokenB provider or tokenA depositer can claim."
        );
        address pool_factory = IUniswapV2Router02(otherPool).factory();
        address pair = IUniswapV2Factory(pool_factory).getPair(tokenA, tokenB);
        uint256 lp_amount = _calculateLPAmount(claimer);
        
        require(lp_amount > claimedLp[claimer], "Exceeded claimable amount");
        
        TransferHelper.safeTransfer(pair, claimer, lp_amount);
        claimedLp[claimer] = lp_amount;
        tokenADeposit[claimer] = 0;

        emit ClaimLP(claimer, lp_amount);
    }

    function claimableLP(address claimer) external view returns (uint256) {
        require(FTOState == Status.Success, "fund rasing not success.");
        uint256 lp_amount = _calculateLPAmount(claimer);
        return lp_amount;
    }

    function _calculateLPAmount(
        address caller
    ) internal view returns (uint256 lp_amount) {
        lp_amount = 0;
        if (tokenBProvider == caller) {
            lp_amount = poolLP >> 1;
        }
        uint256 deposit_amount = tokenADeposit[caller];

        lp_amount = lp_amount + ((deposit_amount * poolLP) >> 1) / reserveA;
    }

    function _perform() internal {
        if (depositedTokenA != 0) {
            // rasing success
            // addLiquidity
            IERC20(tokenA).approve(otherPool, depositedTokenA);
            IERC20(tokenB).approve(otherPool, depositedTokenB);
            (, , uint liquidity) = IUniswapV2Router02(otherPool).addLiquidity(
                tokenA,
                tokenB,
                depositedTokenA,
                depositedTokenB,
                0,
                0,
                address(this),
                block.timestamp + 10
            );
            poolLP = liquidity;
            address pool_factory = IUniswapV2Router02(otherPool).factory();
            address pair = IUniswapV2Factory(pool_factory).getPair(
                tokenA,
                tokenB
            );
            (address token0, ) = tokenA < tokenB
                ? (tokenA, tokenB)
                : (tokenB, tokenA);
            (uint reserve0, uint reserve1, ) = IUniswapV2Pair(pair)
                .getReserves();
            reserveA = tokenA == token0 ? reserve0 : reserve1;
            FTOState = Status.Success;
        } else {
            FTOState = Status.Failed;
        }
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = block.timestamp > endTime;
        performData = "";
    }

    function performUpkeep(bytes calldata) external override {
        require(block.timestamp > endTime, "fund rasing not finished.");
        _perform();
    }
}
