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

    address public tokenB_provider;

    uint256 public deposited_TokenA;
    uint256 public deposited_TokenB;

    address public factory;

    uint256 public start_time = block.timestamp;
    uint256 public end_time;

    address public otherPool;
    uint256 public poolLP;
    uint256 public reserveA;

    Status public ftoState = Status.Processing;

    mapping(address => uint256) public tokenA_deposit;
    mapping(address => uint256) public claimedLp;

    address[] public tokenA_deposit_address;

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
        address _tokenB_provider,
        address _otherPool,
        uint256 raising_cycle
    ) external {
        require(msg.sender == factory, "YexFTOPair: FORBIDDEN"); // sufficient check
        tokenA = _tokenA;
        tokenB = _tokenB;
        tokenB_provider = _tokenB_provider;
        end_time = block.timestamp + raising_cycle;
        otherPool = _otherPool;
    }

    function depositTokenB(
        address depositer,
        uint256 amount
    ) external override {
        require(block.timestamp < end_time, "deposit: raising time is over");
        require(depositer == tokenB_provider, "only Project owner can deposit");
        if (amount == 0) {
            revert InvalidAmount();
        }
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));
        if (balanceB != amount + deposited_TokenB) {
            revert InvalidUpdate();
        }
        deposited_TokenB = deposited_TokenB + amount;
        emit Deposit(depositer, amount);
    }

    function depositTokenA(
        address depositer,
        uint256 amount
    ) external override {
        require(block.timestamp < end_time, "deposit: raising time is over");
        require(
            depositer != tokenB_provider,
            "Project owner are not allowed to deposit with their launch"
        );
        if (amount == 0) {
            revert InvalidAmount();
        }
        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        if (balanceA != amount + deposited_TokenA) {
            revert InvalidUpdate();
        }

        if (tokenA_deposit[depositer] == 0) {
            tokenA_deposit_address.push(depositer);
        }

        tokenA_deposit[depositer] = tokenA_deposit[depositer] + amount;
        deposited_TokenA = deposited_TokenA + amount;

        // update participations
        IYexFTOFactory(factory).addEvent(depositer, address(this));

        emit Deposit(depositer, amount);
    }

    function withdraw(address withdrawer) external override lock {
        require(ftoState == Status.Failed, "fund rasing not failed.");
        require(tokenB_provider == withdrawer, "only provider can withdraw");
        IERC20(tokenB).transfer(withdrawer, deposited_TokenB);
        emit Withdraw(withdrawer, deposited_TokenB);
    }

    function claimLP(address claimer) external lock {
        require(ftoState == Status.Success, "fund rasing not success.");
        require(
            tokenB_provider == claimer || tokenA_deposit[claimer] != 0,
            "only tokenB provider or tokenA depositer can claim."
        );
        address pool_factory = IUniswapV2Router02(otherPool).factory();
        address pair = IUniswapV2Factory(pool_factory).getPair(tokenA, tokenB);
        uint256 lp_amount = _calculateLPAmount(claimer);
        
        require(lp_amount > claimedLp[claimer], "Exceeded claimable amount");
        
        TransferHelper.safeTransfer(pair, claimer, lp_amount);
        claimedLp[claimer] = lp_amount;
        tokenA_deposit[claimer] = 0;

        emit ClaimLP(claimer, lp_amount);
    }

    function claimableLP(address claimer) external view returns (uint256) {
        require(ftoState == Status.Success, "fund rasing not success.");
        uint256 lp_amount = _calculateLPAmount(claimer);
        return lp_amount;
    }

    function _calculateLPAmount(
        address caller
    ) internal view returns (uint256 lp_amount) {
        lp_amount = 0;
        if (tokenB_provider == caller) {
            lp_amount = poolLP >> 1;
        }
        uint256 deposit_amount = tokenA_deposit[caller];

        lp_amount = lp_amount + ((deposit_amount * poolLP) >> 1) / reserveA;
    }

    function _perform() internal {
        if (deposited_TokenA != 0) {
            // rasing success
            // addLiquidity
            IERC20(tokenA).approve(otherPool, deposited_TokenA);
            IERC20(tokenB).approve(otherPool, deposited_TokenB);
            (, , uint liquidity) = IUniswapV2Router02(otherPool).addLiquidity(
                tokenA,
                tokenB,
                deposited_TokenA,
                deposited_TokenB,
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
            ftoState = Status.Success;
        } else {
            ftoState = Status.Failed;
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
        upkeepNeeded = block.timestamp > end_time;
        performData = "";
    }

    function performUpkeep(bytes calldata) external override {
        require(block.timestamp > end_time, "fund rasing not finished.");
        _perform();
    }
}
