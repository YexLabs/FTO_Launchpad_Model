// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/ERC20.sol";
import "../libraries/Math.sol";
import "../libraries/Ownable.sol";
import "../libraries/Console.sol";
import "../interfaces/IYexFTOPair.sol";
import "../interfaces/IYexFTOFactory.sol";
import "../interfaces/IHenloDexRouterV1.sol";
import "../interfaces/IHenloDexFactory.sol";
import "../interfaces/IHenloDexPair.sol";
import "../libraries/TransferHelper.sol";
import "../interfaces/IYexFTOHook.sol";

contract YexFTOPairV3 is IYexFTOPair, ERC20("YexFTOPairV3", "FTOLPV3") {
    uint8 public feePercent = 5; // default is 5%

    address public raisedToken; // tokenA is used to subscribe tokenB

    address public launchedToken; // tokenB is the issuer
    address public launchedTokenProvider;
    uint256 public launchPercent = 100; // launch percentage defaults to 100

    uint256 public depositedRaisedToken;
    uint256 public depositedLaunchedToken;

    address public factory;

    uint256 public startTime = block.timestamp;
    uint256 public endTime;

    address public otherPool;

    // lp
    address public lpToken;
    uint256 public providerClaimedLp;
    uint256 public userClaimedLp;

    Status public FTOState = Status.Processing;

    mapping(address => uint256) public raisedTokenDeposit;
    mapping(address => uint256) public claimedLp;
    mapping(address => bool) public claimedLauncedToken;

    address[] public raisedTokenDepositAddress;

    uint256 public percent4hook; // percentage for hook
    address public hook;

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

    event ClaimLaunchedToken(address claimer, uint256 amount);

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(
        address _raisedToken,
        address _launchedToken,
        address _launchedTokenProvider,
        uint256 _launchedTokenPercent,
        address _otherPool,
        uint256 raisingCycle,
        bytes calldata data
    ) external {
        require(msg.sender == factory, "YexFTOPair: FORBIDDEN"); // sufficient check
        raisedToken = _raisedToken;
        launchedToken = _launchedToken;
        launchedTokenProvider = _launchedTokenProvider;
        launchPercent = _launchedTokenPercent;
        endTime = block.timestamp + raisingCycle;
        otherPool = _otherPool;
        if (data.length > 0) {
            (uint256 _hookPercent, bytes memory _hookParams) = abi.decode(
                data,
                (uint256, bytes)
            );
            hook = _launchedTokenProvider;
            percent4hook = _hookPercent;

            IYexFTOHook(hook).execute(address(this), _hookParams);
        }
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
        uint256 launchedTokenBalance = IERC20(launchedToken).balanceOf(
            address(this)
        );
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
        uint256 raisedTokenBalance = IERC20(raisedToken).balanceOf(
            address(this)
        );
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
        require(deposit_amount > 0, "refundable amount is 0");

        raisedTokenDeposit[depositer] = 0;
        IERC20(raisedToken).transfer(depositer, deposit_amount);

        emit Refund(depositer, deposit_amount);
    }

    function withdraw(address withdrawer) external override lock {
        require(
            FTOState == Status.Failed || FTOState == Status.Paused,
            "fund rasing not failed."
        );
        require(
            launchedTokenProvider == withdrawer,
            "only provider can withdraw"
        );
        IERC20(launchedToken).transfer(withdrawer, depositedLaunchedToken);
        emit Withdraw(withdrawer, depositedLaunchedToken);
    }

    function claimLP(address claimer) external lock {
        require(FTOState == Status.Success, "fund rasing not success.");
        require(
            launchedTokenProvider == claimer ||
                raisedTokenDeposit[claimer] != 0,
            "only launched token provider or raised token depositer can claim."
        );

        uint256 lpAmount = _calculateLPAmount(claimer);
        require(lpAmount - claimedLp[claimer] > 0, "Lp amount is too small.");
        claimedLp[claimer] += lpAmount;

        if (claimer == launchedTokenProvider) {
            providerClaimedLp += lpAmount;
        } else {
            userClaimedLp += lpAmount;
        }

        TransferHelper.safeTransfer(lpToken, claimer, lpAmount);

        emit ClaimLP(claimer, lpAmount);
    }

    function claimableLP(address claimer) external view returns (uint256) {
        require(FTOState == Status.Success, "fund rasing not success.");
        uint256 lpAmount = _calculateLPAmount(claimer);
        return lpAmount - claimedLp[claimer];
    }

    function _calculateLPAmount(
        address caller
    ) internal view returns (uint256 lpAmount) {
        lpAmount = 0;
        uint256 deltaLp = IERC20(lpToken).balanceOf(address(this)) +
            (providerClaimedLp + userClaimedLp);

        if (launchedTokenProvider == caller) {
            lpAmount = deltaLp >> 1;
        }

        lpAmount +=
            ((raisedTokenDeposit[caller] * deltaLp) >> 1) /
            depositedRaisedToken;
    }

    function claimLaunchedToken(address claimer) external lock {
        require(FTOState == Status.Success, "fund rasing not success.");
        require(
            raisedTokenDeposit[claimer] != 0,
            "only raised token depositer can claim."
        );
        require(claimedLauncedToken[claimer] == false, "claimer have claimed.");

        claimedLauncedToken[claimer] = true;

        uint256 amount = _calculateLaunchedTokenAmount(claimer);

        require(amount > 0, "claim amount is too small.");

        TransferHelper.safeTransfer(launchedToken, claimer, amount);

        emit ClaimLaunchedToken(claimer, amount);
    }

    function claimableLaunchedToken(
        address claimer
    ) external view returns (uint256) {
        require(FTOState == Status.Success, "fund rasing not success.");
        uint256 amount = _calculateLaunchedTokenAmount(claimer);
        return amount;
    }

    function _calculateLaunchedTokenAmount(
        address caller
    ) internal view returns (uint256 amount) {
        if (claimedLauncedToken[caller] == true) {
            return 0;
        }
        amount = 0;
        uint256 deposit_amount = raisedTokenDeposit[caller];
        uint256 poolLauncedTokenAmount = IERC20(launchedToken).balanceOf(
            address(this)
        );
        amount =
            (deposit_amount * poolLauncedTokenAmount) /
            depositedRaisedToken;
    }

    function _perform() internal {
        if (depositedRaisedToken != 0) {
            // rasing success
            // addLiquidity
            uint256 launchAmount = (depositedLaunchedToken * launchPercent) /
                100;
            IERC20(raisedToken).approve(otherPool, depositedRaisedToken);
            IERC20(launchedToken).approve(otherPool, launchAmount);
            (, , uint liquidity) = IHenloDexRouterV1(otherPool).addLiquidity(
                raisedToken,
                launchedToken,
                depositedRaisedToken,
                launchAmount,
                0,
                0,
                address(this),
                block.timestamp + 100
            );

            address poolFactory = IHenloDexRouterV1(otherPool).factory();
            address pair = IHenloDexFactory(poolFactory).getPair(
                raisedToken,
                launchedToken
            );
            lpToken = pair;

            // send fee to factory
            uint256 _totalLP = (liquidity * (100 - feePercent)) / 100; // fee percent is 5%
            TransferHelper.safeTransfer(pair, factory, liquidity - _totalLP);

            FTOState = Status.Success;

            // hook part
            if (hook != address(0)) {
                IERC20(pair).approve(hook, (_totalLP * percent4hook) / 100);
                IYexFTOHook(hook).afterAddLiquidity(
                    address(this),
                    launchedToken,
                    (_totalLP * percent4hook) / 100
                );
            }
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
        require(msg.sender == factory, "only factory can pause");
        require(FTOState == Status.Processing, "Launchpad is not in progress");
        FTOState = Status.Paused;
        emit Paused(block.timestamp);
    }

    function resume() external override {
        require(msg.sender == factory, "only factory can resume");
        require(
            FTOState == Status.Paused,
            "Launchpad is in processing or finished"
        );
        FTOState = Status.Processing;
        emit Resumed(block.timestamp);
    }

    function withdrawFee(address feeTo) external override {}
}
