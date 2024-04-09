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
    address public baseToken; // tokenA is used to subscribe tokenB
    address public fairToken; // tokenB is the issuer

    address public fairTokenProvider;

    uint256 public depositedBaseToken;
    uint256 public depositedFairToken;

    address public factory;

    uint256 public startTime = block.timestamp;
    uint256 public endTime;

    address public otherPool;
    uint256 public poolLP;
    uint256 public baseTokenReserve;

    Status public FTOState = Status.Processing;

    mapping(address => uint256) public baseTokenDeposit;
    mapping(address => uint256) public claimedLp;

    address[] public baseTokenDepositAddress;

    error InvalidAmount();
    error InvalidUpdate();

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "YexFTO: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier whenPaused() {
        require(FTOState == Status.Paused, "Project is in progress");
        _;
    }

    modifier whenNotPaused() {
        require(FTOState != Status.Paused, "Project is paused");
        _;
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(
        address _baseToken,
        address _fairToken,
        address _fairTokenProvider,
        address _otherPool,
        uint256 raisingCycle
    ) external {
        require(msg.sender == factory, "YexFTOPair: FORBIDDEN"); // sufficient check
        baseToken = _baseToken;
        fairToken = _fairToken;
        fairTokenProvider = _fairTokenProvider;
        endTime = block.timestamp + raisingCycle;
        otherPool = _otherPool;
    }

    function depositFairToken(
        address depositer,
        uint256 amount
    ) external override whenNotPaused {
        require(block.timestamp < endTime, "deposit: raising time is over");
        require(
            depositer == fairTokenProvider,
            "only Project owner can deposit"
        );
        if (amount == 0) {
            revert InvalidAmount();
        }
        uint256 fairTokenBalance = IERC20(fairToken).balanceOf(address(this));
        if (fairTokenBalance != amount + depositedFairToken) {
            revert InvalidUpdate();
        }
        depositedFairToken = depositedFairToken + amount;
        emit Deposit(depositer, amount);
    }

    function depositBaseToken(
        address depositer,
        uint256 amount
    ) external override whenNotPaused {
        require(block.timestamp < endTime, "deposit: raising time is over");
        require(
            depositer != fairTokenProvider,
            "Project owner are not allowed to deposit with their launch"
        );
        if (amount == 0) {
            revert InvalidAmount();
        }
        uint256 baseTokenBalance = IERC20(baseToken).balanceOf(address(this));
        if (baseTokenBalance != amount + depositedBaseToken) {
            revert InvalidUpdate();
        }

        if (baseTokenDeposit[depositer] == 0) {
            baseTokenDepositAddress.push(depositer);
        }

        baseTokenDeposit[depositer] = baseTokenDeposit[depositer] + amount;
        depositedBaseToken = depositedBaseToken + amount;

        // update participations
        IYexFTOFactory(factory).addEvent(depositer, address(this));

        emit Deposit(depositer, amount);
    }

    function refundBaseToken(
        address depositer
    ) external override lock whenPaused {
        require(block.timestamp < endTime, "deposit: raising time is over");
        require(
            depositer != fairTokenProvider,
            "Project owner are not allowed to refund"
        );
        uint256 deposit_amount = baseTokenDeposit[depositer];
       
        IERC20(baseToken).transfer(depositer, deposit_amount);
        baseTokenDeposit[depositer] = 0;

        emit Refund(depositer, deposit_amount);
    }

    function withdraw(address withdrawer) external override lock {
        require(FTOState == Status.Failed || FTOState == Status.Paused, "fund rasing not failed.");
        require(fairTokenProvider == withdrawer, "only provider can withdraw");
        IERC20(fairToken).transfer(withdrawer, depositedFairToken);
        emit Withdraw(withdrawer, depositedFairToken);
    }

    function claimLP(address claimer) external lock {
        require(FTOState == Status.Success, "fund rasing not success.");
        require(
            fairTokenProvider == claimer || baseTokenDeposit[claimer] != 0,
            "only fair token provider or base token depositer can claim."
        );
        address poolFactory = IUniswapV2Router02(otherPool).factory();
        address pair = IUniswapV2Factory(poolFactory).getPair(
            baseToken,
            fairToken
        );
        uint256 lpAmount = _calculateLPAmount(claimer);

        require(lpAmount > claimedLp[claimer], "Exceeded claimable amount");

        TransferHelper.safeTransfer(pair, claimer, lpAmount);
        claimedLp[claimer] = lpAmount;
        baseTokenDeposit[claimer] = 0;

        emit ClaimLP(claimer, lpAmount);
    }
    
    function claimableLP(address claimer) external view returns (uint256) {
        require(FTOState == Status.Success, "fund rasing not success.");
        uint256 lpAmount = _calculateLPAmount(claimer);
        return lpAmount;
    }

    function _calculateLPAmount(
        address caller
    ) internal view returns (uint256 lpAmount) {
        lpAmount = 0;
        if (fairTokenProvider == caller) {
            lpAmount = poolLP >> 1;
        }
        uint256 deposit_amount = baseTokenDeposit[caller];

        lpAmount =
            lpAmount +
            ((deposit_amount * poolLP) >> 1) /
            baseTokenReserve;
    }

    function _perform() internal {
        if (depositedBaseToken != 0) {
            // rasing success
            // addLiquidity
            IERC20(baseToken).approve(otherPool, depositedBaseToken);
            IERC20(fairToken).approve(otherPool, depositedFairToken);
            (, , uint liquidity) = IUniswapV2Router02(otherPool).addLiquidity(
                baseToken,
                fairToken,
                depositedBaseToken,
                depositedFairToken,
                0,
                0,
                address(this),
                block.timestamp + 10
            );
            poolLP = liquidity;
            address poolFactory = IUniswapV2Router02(otherPool).factory();
            address pair = IUniswapV2Factory(poolFactory).getPair(
                baseToken,
                fairToken
            );
            (address token0, ) = baseToken < fairToken
                ? (baseToken, fairToken)
                : (fairToken, baseToken);
            (uint reserve0, uint reserve1, ) = IUniswapV2Pair(pair)
                .getReserves();
            baseTokenReserve = baseToken == token0 ? reserve0 : reserve1;
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

    function pause() external override {
        require(block.timestamp < endTime, "fund rasing finished.");
        require(fairTokenProvider == tx.origin, "only provider can withdraw");
        FTOState = Status.Paused;
        emit Paused(block.timestamp);
    }

    function resume() external override {
        require(fairTokenProvider == tx.origin, "only provider can withdraw");
        FTOState = Status.Processing;
        emit Resumed(block.timestamp);
    }
}
