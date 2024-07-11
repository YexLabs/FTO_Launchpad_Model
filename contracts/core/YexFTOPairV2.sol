// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../interfaces/IYexFTOPair.sol";
import "../interfaces/IYexFTOFactoryV2.sol";
import "../interfaces/IHenloDexRouterV1.sol";
import "../interfaces/IHenloDexFactory.sol";
import "../interfaces/IHenloDexPair.sol";
import "../interfaces/IYexFTOHook.sol";
import "../libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Contract that manages the FTO Launchpad
/// @notice Created from the FTO Factory contract
/// @dev This contract address is uniquely determined by the RaisedToken and LaunchedToken.
contract YexFTOPairV2 is IYexFTOPair {
    /// @dev The percentage of LP tokens received after adding liquidity to the AMM Pool that is paid to the Factory as a fee
    /// The decimal for feePercent is 0.
    uint8 public feePercent = 5;

    /// @dev Address of Raised Token
    /// This value is set when the initialize function is called by the FTOFactory and does not change once set.
    address public raisedToken;
    /// @dev Address of Launched Token
    /// This value is set when the initialize function is called by the FTOFactory and does not change once set.
    address public launchedToken;

    /// @dev The amount of Launched Token to be provided as a reward to depositors
    /// poolLaunchedTokenAmount = depositedLaunchedToken * (100 - launchPercent) / 100
    uint256 public poolLaunchedTokenAmount;

    /// @dev The entity that created the FTO Launchpad
    /// The address of the Token Launcher if CustomHook is not used,
    /// or the hook address if CustomHook is used.
    address public launchedTokenProvider;
    /// @dev The amount of LaunchedToken added as liquidity to the AMM Pool, excluding the amount provided as a reward to depositors
    /// rewardPercent = 100 - launchPercent
    /// launchPercent defaults to 100%
    uint256 public launchPercent = 100;

    /// @dev The amount of RaisedToken deposited to address(this): FTOPair
    uint256 public depositedRaisedToken;
    /// @dev The amount of LaunchedToken in the address(this): FTOPair
    uint256 public depositedLaunchedToken;

    /// @dev The address of YexFTOFactory contract
    address public immutable factory;

    /// @dev The time when the fundraising for the FTO begins
    /// Fundraising begins immediately upon the creation of the FTOPair contract.
    uint256 public startTime = block.timestamp;
    /// @dev The time when the fundraising for the FTO ends
    /// It is set in the initialize function.
    uint256 public endTime;

    /// @dev The address of HenloDexRouter
    address public otherPool;

    /// @dev The address of the LP tokens received after adding liquidity to HenloDex
    address public lpToken;
    /// @dev The amount of LP tokens claimed by the Token Provider
    /// The Token Provider can claim 50% of the LP tokens.
    uint256 public providerClaimedLp;
    /// @dev The total amount of LP tokens claimed by depositors
    /// Depositors can claim from 50% of the LP tokens in proportion to their share of the deposited RaisedToken.
    uint256 public userClaimedLp;

    /// @dev Indicates the status of the FTO. The status can be [Processing], [Paused], [Success], or [Failed].
    Status public FTOState = Status.Processing;

    /// @dev The amount of RaisedToken deposited by each depositor
    /// It is used to calculate the share of each depositor.
    mapping(address => uint256) public raisedTokenDeposit;
    /// @dev The amount of LP tokens claimed by each user.
    /// A user can be either a depositor or a token provider.
    mapping(address => uint256) public claimedLp;
    /// @dev Indicates whether each depositor has claimed the LaunchedToken allocated as a reward
    mapping(address => bool) public claimedLaunchedToken;

    /// @dev List of depositors
    address[] public raisedTokenDepositAddress;

    /// @dev The percentage of LP tokens that are vested in hook contract if the FTO uses a vesting hook.
    /// It is set in the initialize function, and the decimal is 0.
    uint256 public percent4hook;
    /// @dev The address of the hook contract if the FTO uses a custom hook
    /// The hook is initially set in the initialize function.
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

    /// @dev This function performs the initial setup for the FTOPair.
    /// This function can only be called by the FTOFactory and is called only once at the time of FTOPair deployment.
    /// @param _raisedToken Token address for investment in FTO fundraising
    /// @param _launchedToken The address of LaunchedToken
    /// @param _launchedTokenProvider When not using a custom hook, the address of the Token Launcher; when using a custom hook, the address of the hook contract
    /// @param _launchedTokenPercent The proportion of LaunchedToken added to the DEX Pool
    /// @param _otherPool The router address of DEX
    /// @param raisingCycle Fundraising period (in seconds)
    /// @param data Data to be passed to the hook contract; empty if FTO does not use a custom hook
    function initialize(
        address _raisedToken,
        address _launchedToken,
        address _launchedTokenProvider,
        uint256 _launchedTokenPercent,
        address _otherPool,
        uint256 raisingCycle,
        bytes calldata data
    ) external {
        // This function reverts if the caller is not the FTOFactory.
        require(msg.sender == factory, "YexFTOPair: FORBIDDEN");

        raisedToken = _raisedToken;
        launchedToken = _launchedToken;
        launchedTokenProvider = _launchedTokenProvider;
        launchPercent = _launchedTokenPercent;

        // Calculates the end time of the FTO fundraising.
        endTime = block.timestamp + raisingCycle;

        otherPool = _otherPool;

        // When data is not empty, it is assumed that _launchedTokenProvider is a hook.
        if (data.length > 0) {
            /**
             * _hookPercent: The percentage of LP tokens that are vested in hook contract
             * _hookParams: Data passed to the hook contract.
             */
            (uint256 _hookPercent, bytes memory _hookParams) = abi.decode(
                data,
                (uint256, bytes)
            );

            // Future updates: Need to verify if _launchedTokenProvider is indeed a hook contract.
            hook = _launchedTokenProvider;
            percent4hook = _hookPercent;

            /**
             * If the hook provides vesting functionality,
             *      _hookParams contains vesting info,
             *      and the [execute] function records the vesting for this FTOPair in the hook.
             * Future updates: Need to check if the hook contract supports the [execute] function.
             */
            IYexFTOHook(hook).execute(_hookParams);
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

    /// @dev Function called after depositors deposit RaisedToken into the FTOPair
    /// This function will not revert if the following conditions are met:
    ///  1. The depositor first transfers the amount of RaisedToken to address(this).
    ///  2. After [1] is completed, this function is called with the depositor and amount as parameters.
    ///  3. The FTO status must be [Processing] and it must be during the fundraising period.
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

        /**
         * This function will revert
         * if the depositor has not transferred [amount] of RaisedToken to address(this) before calling it.
         */
        if (raisedTokenBalance != amount + depositedRaisedToken) {
            revert InvalidUpdate();
        }

        /**
         * If the depositor is depositing RaisedToken for the first time,
         * add it to the depositor list of the FTOPair.
         */
        if (raisedTokenDeposit[depositor] == 0) {
            raisedTokenDepositAddress.push(depositor);
        }

        /**
         * Update the depositor's RaisedToken deposit amount
         *  and the total amount of RaisedToken deposited in the FTOPair.
         */
        raisedTokenDeposit[depositor] = raisedTokenDeposit[depositor] + amount;
        depositedRaisedToken = depositedRaisedToken + amount;

        /**
         * The addEvent function in the FTOFactory updates the storage variable
         *  to reflect that the depositor has participated in this FTOPair.
         */
        IYexFTOFactoryV2(factory).addEvent(depositor, address(this));

        emit DepositRaisedToken(depositor, amount);
    }

    /// @dev Transfer the entire amount of RaisedToken deposited back to the depositor's address.
    /// Can only be called if the FTO status is [Paused].
    /// @param depositor Address of the depositor who requested a refund of RaisedToken.
    function refundRaisedToken(
        address depositor
    ) external override lock whenPaused {
        // Verify that the depositor is a valid address that had deposited RaisedToken.
        uint256 deposit_amount = raisedTokenDeposit[depositor];
        require(deposit_amount > 0, "refundable amount is 0");

        raisedTokenDeposit[depositor] = 0;
        depositedRaisedToken -= deposit_amount;

        IERC20(raisedToken).transfer(depositor, deposit_amount);

        emit Refund(depositor, deposit_amount);
    }

    /// @dev Transfer all LaunchedToken in the FTOPair to the [withdrawer] address.
    /// @param withdrawer The address to receive the withdrawn LaunchedToken; This must be launchedTokenProvider
    function withdraw(address withdrawer) external override lock {
        /**
         * Can only be called if the FTO status is Failed or Paused.
         * If there are no RaisedToken deposits at the end of the fundraising period,
         *  the FTO status becomes Failed.
         */
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

    /// @dev Function that allows the [claimer] to claim LP tokens
    /// The amount the [claimer] can claim is calculated within the function.
    /// This function can only be called after the fundraising is completed,
    ///   liquidity has been added to the Dex pool, and the FTO status is set to Success.
    /// @param claimer The address claiming the LP tokens; the address receiving the LP tokens
    function claimLP(address claimer) external lock {
        require(FTOState == Status.Success, "fund rasing not success.");
        /**
         * The [claimer] must be either the launchedTokenProvider
         *  or a depositor who deposited RaisedToken.
         */
        require(
            claimer == launchedTokenProvider ||
                raisedTokenDeposit[claimer] != 0,
            "only launched token provider or raised token depositer can claim."
        );

        /**
         * lpAmount is the amount of LP tokens the claimer can claim.
         * lpAmount includes the LP tokens the claimer has already claimed.
         * Therefore, the condition lpAmount > claimedAmount must be satisfied.
         */
        uint256 lpAmount = _calculateLPAmount(claimer);
        uint256 claimedAmount = claimedLp[claimer];
        require(lpAmount > claimedAmount, "LP amount is too small.");

        // claimableAmount is the actual amount of LP tokens being claimed by the claimer.
        uint256 claimableAmount = lpAmount - claimedAmount;

        // At this point, the amount of LP tokens claimed by the claimer becomes lpAmount.
        claimedLp[claimer] = lpAmount;

        /**
         * Update the claimed amount in different tracking state variables
         *  depending on whether the claimer is the launchedTokenProvider or a common depositor.
         */
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

        claimedLaunchedToken[claimer] = true;

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
        if (claimedLaunchedToken[caller]) {
            return 0;
        }

        uint256 deposit_amount = raisedTokenDeposit[caller];

        amount =
            (deposit_amount * poolLaunchedTokenAmount) /
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

            // hook part
            if (hook != address(0)) {
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
