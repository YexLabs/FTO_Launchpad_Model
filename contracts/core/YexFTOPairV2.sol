// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../interfaces/IYexFTOPairV2.sol";
import "../interfaces/IYexFTOFactoryV2.sol";
import "../interfaces/IHenloDexRouterV1.sol";
import "../interfaces/IHenloDexFactory.sol";
import "../interfaces/IHenloDexPair.sol";
import "../interfaces/IYexFTOHook.sol";
import "../libraries/TransferHelper.sol";
import "../libraries/YexFTOHook.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract YexFTOPairV2 is IYexFTOPairV2 {
    using YexFTOHook for address;

    uint8 public feePercent = 5; // default is 5%

    address public raisedToken; // raisedToken is used to subscribe tokenB
    address public launchedToken; // launchedToken is the issuer

    uint256 public poolLaunchedTokenAmount; // default is 0;

    address public launchedTokenProvider;
    uint256 public launchPercent = 100; // launch percentage defaults to 100

    uint256 public depositedRaisedToken;
    uint256 public depositedLaunchedToken;

    address public immutable factory;

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
    mapping(address => bool) public claimedLaunchedToken;

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
        if (data.length > 0 && _launchedTokenProvider.isValidHookAddress()) {
            (uint256 _hookPercent, bytes memory _hookParams) = abi.decode(
                data,
                (uint256, bytes)
            );
            hook = _launchedTokenProvider;
            percent4hook = _hookPercent;

            if(hook.hasExecute()) {
                IYexFTOHook(hook).execute(_hookParams);
            }
        }
    }

    function depositLaunchedToken(
        address depositor,
        uint256 amount
    ) external override whenNotPaused {
        require(block.timestamp < endTime, "deposit: raising time is over");
        require(
            depositor == launchedTokenProvider,
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
        emit DepositLaunchedToken(depositor, amount);
    }

    function depositRaisedToken(
        address depositor,
        uint256 amount
    ) external override whenNotPaused {
        require(block.timestamp < endTime, "deposit: raising time is over");
        require(
            depositor != launchedTokenProvider,
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

        raisedTokenDeposit[depositor] = raisedTokenDeposit[depositor] + amount;
        depositedRaisedToken = depositedRaisedToken + amount;

        // update participations
        IYexFTOFactoryV2(factory).addEvent(depositor, address(this));

        emit DepositRaisedToken(depositor, amount);
    }

    function refundRaisedToken(
        address depositor
    ) external override lock whenPaused {
        uint256 deposit_amount = raisedTokenDeposit[depositor];
        require(deposit_amount > 0, "refundable amount is 0");

        raisedTokenDeposit[depositor] = 0;
        depositedRaisedToken -= deposit_amount;

        IERC20(raisedToken).transfer(depositor, deposit_amount);

        emit Refund(depositor, deposit_amount);
    }

    function withdraw(address withdrawer) external override lock {
        require(
            FTOState == Status.Failed || FTOState == Status.Paused,
            "fund raising has already concluded"
        );
        require(
            launchedTokenProvider == withdrawer,
            "only provider can withdraw"
        );
        uint256 withdraw_amount = depositedLaunchedToken;
        depositedLaunchedToken = 0;

        IERC20(launchedToken).transfer(withdrawer, withdraw_amount);
        emit Withdraw(withdrawer, withdraw_amount);
    }

    /// @notice provider need direct call pair claimLP function.
    function claimLP(address claimer) external lock {
        require(FTOState == Status.Success, "fund rasing not success.");
        require(
            raisedTokenDeposit[claimer] != 0 ||
            (claimer == launchedTokenProvider && !hook.hasBurnable()),
            "only launched token provider or raised token depositer can claim."
        );

        uint256 lpAmount = _calculateLPAmount(claimer);
        uint256 claimedAmount = claimedLp[claimer];
        require(lpAmount > claimedAmount, "LP amount is too small.");

        uint256 claimableAmount = lpAmount - claimedAmount;
        claimedLp[claimer] = lpAmount;

        if (claimer == launchedTokenProvider) {
            providerClaimedLp += claimableAmount;
        } else {
            userClaimedLp += claimableAmount;
        }

        TransferHelper.safeTransfer(lpToken, claimer, claimableAmount);

        emit ClaimLP(claimer, claimableAmount);
    }

    function claimableLP(address claimer) external view returns (uint256) {
        require(FTOState == Status.Success, "fund rasing not success.");
        uint256 lpAmount = _calculateLPAmount(claimer);
        return lpAmount - claimedLp[claimer];
    }

    function _calculateLPAmount(
        address caller
    ) internal view returns (uint256 lpAmount) {
        uint256 cumulativeLP = IERC20(lpToken).balanceOf(address(this)) +
            (providerClaimedLp + userClaimedLp);

        lpAmount = cumulativeLP >> 1;

        if (launchedTokenProvider != caller) {
            lpAmount =
                (raisedTokenDeposit[caller] * lpAmount) /
                depositedRaisedToken;
        }
    }

    function claimLaunchedToken(address claimer) external lock {
        require(FTOState == Status.Success, "fund rasing not success.");
        require(
            raisedTokenDeposit[claimer] != 0,
            "only raised token depositer can claim."
        );
        require(!claimedLaunchedToken[claimer], "claimer has claimed.");

        uint256 amount = _calculateLaunchedTokenAmount(claimer);
        require(amount > 0, "claim amount is too small.");

        claimedLaunchedToken[claimer] = true;

        TransferHelper.safeTransfer(launchedToken, claimer, amount);

        emit ClaimLaunchedToken(claimer, amount);
    }

    function claimableLaunchedToken(
        address claimer
    ) external view returns (uint256) {
        require(FTOState == Status.Success, "fund rasing not success.");
        uint256 amount = claimedLaunchedToken[claimer] ? 0 : _calculateLaunchedTokenAmount(claimer);
        return amount;
    }

    function _calculateLaunchedTokenAmount(
        address caller
    ) internal view returns (uint256 amount) {
        amount =
            (raisedTokenDeposit[caller] * poolLaunchedTokenAmount) /
            depositedRaisedToken;
    }

    function _perform() internal {
        if (depositedRaisedToken != 0) {
            // rasing success
            // addLiquidity
            uint256 launchAmount = (depositedLaunchedToken * launchPercent) /
                100;
            poolLaunchedTokenAmount = depositedLaunchedToken - launchAmount;
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

            if (hook != address(0) && hook.hasAfterAddLiquidity()) {
                uint256 vestAmount = (_totalLP * percent4hook) / 100;
                IERC20(pair).approve(hook, vestAmount);
                IYexFTOHook(hook).afterAddLiquidity(
                    address(this),
                    pair,
                    vestAmount
                );
            }
        } else {
            FTOState = Status.Failed;
        }
    }

    function _isUpkeepNeeded() internal view returns (bool) {
        return block.timestamp > endTime && FTOState == Status.Processing;
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = _isUpkeepNeeded();
        performData = "";
    }

    function performUpkeep(bytes calldata) external override {
        require(_isUpkeepNeeded(), "fund raising not finished or paused");
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
