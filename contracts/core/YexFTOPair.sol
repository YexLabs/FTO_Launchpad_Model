// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/ERC20.sol";
import "../libraries/Math.sol";
import "../interfaces/IYexFTOPair.sol";
import "../interfaces/IYexFTOFactory.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IYexFTOHook.sol";
import "../libraries/TransferHelper.sol";
import "../libraries/AccessControl.sol";

contract YexFTOPair is IYexFTOPair, ERC20("YexFTOPair", "FTOLP") {
    address public raisedToken; // tokenA is used to subscribe tokenB
    address public launchedToken; // tokenB is the issuer
    address public hook;

    address public launchedTokenProvider;

    uint256 public depositedRaisedToken;
    uint256 public depositedLaunchedToken;

    //claim
    uint256 public providerLPBalance;
    uint256 public userLPBalance;
    uint256 public userLPAccBalance;

    address public factory;

    uint256 public startTime = block.timestamp;
    uint256 public endTime;

    address public otherPool;
    address public lpToken;

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
        uint256 raisingCycle,
        address _hook
    ) external {
        require(msg.sender == factory, "YexFTOPair: FORBIDDEN"); // sufficient check
        raisedToken = _raisedToken;
        launchedToken = _launchedToken;
        launchedTokenProvider = _launchedTokenProvider;
        endTime = block.timestamp + raisingCycle;
        otherPool = _otherPool;
        hook = _hook;
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

        TransferHelper.safeTransfer(raisedToken, depositer, deposit_amount);

        emit Refund(depositer, deposit_amount);
    }

    function withdraw(address withdrawer) external override lock {
        require(FTOState == Status.Failed || FTOState == Status.Paused, "fund rasing not failed.");
        require(launchedTokenProvider == withdrawer, "only provider can withdraw");
        
        IERC20(launchedToken).transfer(withdrawer, depositedLaunchedToken);
        
        emit Withdraw(withdrawer, depositedLaunchedToken);
    }

    function _perform() internal {
        if (depositedRaisedToken != 0) {
            TransferHelper.safeApprove(raisedToken, otherPool, depositedRaisedToken);

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

            address poolFactory = IUniswapV2Router02(otherPool).factory();
            address pair = IUniswapV2Factory(poolFactory).getPair(
                raisedToken,
                launchedToken
            );

            lpToken = pair;
            FTOState = Status.Success;

            //hook part
            TransferHelper.safeApprove(pair, hook, liquidity);
            (providerLPBalance, userLPBalance) = IYexFTOHook(hook).afterAddLiquidity(pair, liquidity);
            userLPAccBalance = userLPBalance;
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

    function performUpkeep(bytes calldata) external override lock {
        require(block.timestamp > endTime, "fund rasing not finished.");
        _perform();
    }

    function claimLP(address claimer, uint256 amount) external lock {
        require(FTOState == Status.Success, "fund rasing not success.");
        require(
            _msgSender() == hook || raisedTokenDeposit[claimer] != 0,
            "only launched token provider or raised token depositer can claim."
        );
        
        uint256 totalLPBalance = IERC20(lpToken).balanceOf(address(this));
        uint256 _providerLPBalance = providerLPBalance;
        uint256 _userLPBalance = userLPBalance;
        uint256 _userLPAccBalance = userLPAccBalance;
        uint256 _claimed = claimedLp[claimer];

        uint256 deltaBalance = totalLPBalance - (_providerLPBalance + _userLPBalance);

        if (deltaBalance > 0) {
            deltaBalance = deltaBalance >> 1;
            _providerLPBalance += deltaBalance;
            _userLPBalance += deltaBalance;
            _userLPAccBalance += deltaBalance;
        }

        uint256 claimable;
        if (_msgSender() == hook) {
            claimable = _providerLPBalance;
        } else {
            uint256 userShareAmount = (_userLPAccBalance * raisedTokenDeposit[claimer]) / depositedRaisedToken;
            claimable = userShareAmount - _claimed;
        }

        require(amount <= claimable, "YexFTOPair: claim amount exceeds claimable amount");

        if (_msgSender() == hook) {
            _providerLPBalance -= amount;
        } else {
            _userLPBalance -= amount;
            _claimed += amount;
        }

        providerLPBalance = _providerLPBalance;
        userLPBalance = _userLPBalance;
        userLPAccBalance = _userLPAccBalance;
        claimedLp[claimer] = _claimed;

        TransferHelper.safeTransfer(lpToken, claimer, amount);
    }

    function claimableAmount(address user) public view returns (uint256) {
        require(FTOState == Status.Success, "fund rasing not success.");

        uint256 totalLPBalance = IERC20(lpToken).balanceOf(address(this));
        uint256 deltaBalance = totalLPBalance - (providerLPBalance + userLPBalance);

        deltaBalance = deltaBalance >> 1;

        if (user == launchedTokenProvider) {
            return providerLPBalance + deltaBalance;
        }
        else {
            uint256 newUserLPAccBalance = userLPAccBalance + deltaBalance;
            uint256 userShareAmount = (newUserLPAccBalance * raisedTokenDeposit[user]) / depositedRaisedToken;   

            return userShareAmount - claimedLp[user];
        }
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
