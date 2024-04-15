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
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract YexFTOPair is IYexFTOPair, ERC20("YexFTOPair", "FTOLP"), IERC165 {

    address public raisedToken; // tokenA is used to subscribe tokenB
    address public launchedToken; // tokenB is the issuer

    address public launchedTokenProvider;

    uint256 public depositedRaisedToken;
    uint256 public depositedLaunchedToken;

    address public factory;

    uint256 public startTime = block.timestamp;
    uint256 public endTime;

    address public otherPool;
    uint256 public poolLP;
    uint256 public raisedTokenReserve;

    Status public FTOState = Status.Processing;

    mapping(address => uint256) public raisedTokenDeposit;
    mapping(address => uint256) public claimedLp;

    address[] public raisedTokenDepositAddress;

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
        address _raisedToken,
        address _launchedToken,
        address _launchedTokenProvider,
        address _otherPool,
        uint256 raisingCycle
    ) external {
        require(msg.sender == factory, "YexFTOPair: FORBIDDEN"); // sufficient check
        raisedToken = _raisedToken;
        launchedToken = _launchedToken;
        launchedTokenProvider = _launchedTokenProvider;
        endTime = block.timestamp + raisingCycle;
        otherPool = _otherPool;
    }

    // ERC165 Interface ID for MyInterface
    bytes4 private constant _INTERFACE_ID_MY_INTERFACE = type(IYexFTOPair).interfaceId;

    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return interfaceId == _INTERFACE_ID_MY_INTERFACE;
    }

    function depositLaunchedToken(
        address depositer,
        uint256 amount
    ) external override whenNotPaused {
        require(block.timestamp < endTime, "deposit: raising time is over");
        require(
            depositer == launchedTokenProvider,
            "only Project owner can deposit"
        );
        if (amount == 0) {
            revert InvalidAmount();
        }
        uint256 launchedTokenBalance = IERC20(launchedToken).balanceOf(address(this));
        if (launchedTokenBalance != amount + depositedLaunchedToken) {
            revert InvalidUpdate();
        }
        depositedLaunchedToken = depositedLaunchedToken + amount;
        emit Deposit(depositer, amount);
    }

    function depositRaisedToken(
        address depositer,
        uint256 amount
    ) external override whenNotPaused {
        require(block.timestamp < endTime, "deposit: raising time is over");
        require(
            depositer != launchedTokenProvider,
            "Project owner are not allowed to deposit with their launch"
        );
        if (amount == 0) {
            revert InvalidAmount();
        }
        uint256 raisedTokenBalance = IERC20(raisedToken).balanceOf(address(this));
        if (raisedTokenBalance != amount + depositedRaisedToken) {
            revert InvalidUpdate();
        }

        if (raisedTokenDeposit[depositer] == 0) {
            raisedTokenDepositAddress.push(depositer);
        }

        raisedTokenDeposit[depositer] = raisedTokenDeposit[depositer] + amount;
        depositedRaisedToken = depositedRaisedToken + amount;

        // update participations
        IYexFTOFactory(factory).addEvent(depositer, address(this));

        emit Deposit(depositer, amount);
    }

    function refundRaisedToken(
        address depositer
    ) external override lock whenPaused {
        require(block.timestamp < endTime, "deposit: raising time is over");
        uint256 deposit_amount = raisedTokenDeposit[depositer];
        require(
            deposit_amount > 0,
            "refundable amount is 0"
        );
       
        raisedTokenDeposit[depositer] = 0;
        IERC20(raisedToken).transfer(depositer, deposit_amount);

        emit Refund(depositer, deposit_amount);
    }

    function withdraw(address withdrawer) external override lock {
        require(FTOState == Status.Failed || FTOState == Status.Paused, "fund rasing not failed.");
        require(launchedTokenProvider == withdrawer, "only provider can withdraw");
        IERC20(launchedToken).transfer(withdrawer, depositedLaunchedToken);
        emit Withdraw(withdrawer, depositedLaunchedToken);
    }

    function claimLP(address claimer) external lock {
        require(FTOState == Status.Success, "fund rasing not success.");
        require(
            launchedTokenProvider == claimer || raisedTokenDeposit[claimer] != 0,
            "only launched token provider or raised token depositer can claim."
        );
        address poolFactory = IUniswapV2Router02(otherPool).factory();
        address pair = IUniswapV2Factory(poolFactory).getPair(
            raisedToken,
            launchedToken
        );
        uint256 lpAmount = _calculateLPAmount(claimer);

        require(lpAmount > claimedLp[claimer], "Exceeded claimable amount");

        TransferHelper.safeTransfer(pair, claimer, lpAmount);
        claimedLp[claimer] = lpAmount;
        raisedTokenDeposit[claimer] = 0;

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
        if (launchedTokenProvider == caller) {
            lpAmount = poolLP >> 1;
        }
        uint256 deposit_amount = raisedTokenDeposit[caller];

        lpAmount =
            lpAmount +
            ((deposit_amount * poolLP) >> 1) /
            raisedTokenReserve;
    }

    function _perform() internal {
        if (depositedRaisedToken != 0) {
            // rasing success
            // addLiquidity
            IERC20(raisedToken).approve(otherPool, depositedRaisedToken);
            IERC20(launchedToken).approve(otherPool, depositedLaunchedToken);
            (, , uint liquidity) = IUniswapV2Router02(otherPool).addLiquidity(
                raisedToken,
                launchedToken,
                depositedRaisedToken,
                depositedLaunchedToken,
                0,
                0,
                address(this),
                block.timestamp + 10
            );
            poolLP = liquidity;
            address poolFactory = IUniswapV2Router02(otherPool).factory();
            address pair = IUniswapV2Factory(poolFactory).getPair(
                raisedToken,
                launchedToken
            );
            (address token0, ) = raisedToken < launchedToken
                ? (raisedToken, launchedToken)
                : (launchedToken, raisedToken);
            (uint reserve0, uint reserve1, ) = IUniswapV2Pair(pair)
                .getReserves();
            raisedTokenReserve = raisedToken == token0 ? reserve0 : reserve1;
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
        require(msg.sender == factory, "only factory can pause");
        require(FTOState == Status.Processing, "Launchpad is not in progress");
        FTOState = Status.Paused;
        emit Paused(block.timestamp);
    }

    function resume() external override {
        require(block.timestamp < endTime, "fund rasing finished.");
        require(msg.sender == factory, "only factory can resume");
        require(FTOState == Status.Paused, "Launchpad is in processing or finished");
        FTOState = Status.Processing;
        emit Resumed(block.timestamp);
    }
}
