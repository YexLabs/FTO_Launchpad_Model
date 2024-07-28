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

/// @title Contract that manages the FTO Launchpad
/// @notice Created from the FTO Factory contract
/// @dev This contract address is uniquely determined by the RaisedToken and LaunchedToken.
contract YexFTOPairV2 is IYexFTOPairV2 {
    using YexFTOHook for address;

    enum FTOPairErrorCode {
        NotInProcessing,
        Paused,
        NotPaused,
        NotSuccess,
        NotFinishedOrPaused
    }

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

    /// @dev The total amount of LP tokens claimed by the TokenLauncher and depositors.
    uint256 public totalClaimedLp;

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

    uint private unlocked = 1;

    /// @dev errors
    error Locked();
    error InvalidAmount();
    error NotDepositedRaisedToken();
    error FTOPairStatusError(FTOPairErrorCode code);
    error Unauthorized(address caller);
    error RaisingTimeIsOver(uint256 currentTime, uint256 endTime);
    error ProjectOwnerDepositNotAllowed(address depositor);
    error NoClaimAmountRemaining(uint256 lpAmount, uint256 claimedAmount);
    error LaunchedTokenAlreadyClaimed(address claimer);
    error NotDepositor(address claimer);

    modifier lock() {
        if (unlocked == 0) {
            revert Locked();
        }

        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier whenPaused() {
        if (FTOState != Status.Paused) {
            revert FTOPairStatusError(FTOPairErrorCode.NotPaused);
        }
        _;
    }

    modifier whenNotPaused() {
        if (FTOState == Status.Paused) {
            revert FTOPairStatusError(FTOPairErrorCode.Paused);
        }
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
        if (msg.sender != factory) {
            revert Unauthorized(msg.sender);
        }

        raisedToken = _raisedToken;
        launchedToken = _launchedToken;
        launchedTokenProvider = _launchedTokenProvider;
        launchPercent = _launchedTokenPercent;
        // LauncheToken has already been minted in the FTOPair.
        depositedLaunchedToken = IERC20(_launchedToken).balanceOf(
            address(this)
        );

        // Calculates the end time of the FTO fundraising.
        endTime = block.timestamp + raisingCycle;

        otherPool = _otherPool;

        /**
         * If the data is not empty and _launchedTokenProvider supports the IYexFTOHook interface,
         *  _launchedTokenProvider is considered a hook, and this FTOPair is determined to use a custom hook.
         */
        if (
            data.length > 0 &&
            _launchedTokenProvider.supportsInterface(
                type(IYexFTOHook).interfaceId
            )
        ) {
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
             * _launchedTokenProvider.hasExecute(): Check if the execute function is defined in the hook contract.
             */
            if (_launchedTokenProvider.hasExecute()) {
                IYexFTOHook(_launchedTokenProvider).execute(_hookParams);
            }
        }
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
        if (block.timestamp >= endTime) {
            revert RaisingTimeIsOver(block.timestamp, endTime);
        }

        if (depositor == launchedTokenProvider) {
            revert ProjectOwnerDepositNotAllowed(depositor);
        }

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
        if (raisedTokenBalance < amount + depositedRaisedToken) {
            revert NotDepositedRaisedToken();
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
    /// The depositor must call this function directly.
    function refundRaisedToken() external override lock whenPaused {
        // Verify that msg.sender is a valid address that had deposited RaisedToken.
        uint256 deposit_amount = raisedTokenDeposit[msg.sender];
        if (deposit_amount == 0) {
            revert InvalidAmount();
        }

        raisedTokenDeposit[msg.sender] = 0;
        depositedRaisedToken -= deposit_amount;

        IERC20(raisedToken).transfer(msg.sender, deposit_amount);

        emit Refund(msg.sender, deposit_amount);
    }

    /// @dev Function that allows the [msg.sender] to claim LP tokens
    /// This function can only be called by a hook contract that has a burnable function.
    /// This function can only be called after the fundraising is completed,
    ///   liquidity has been added to the Dex pool, and the FTO status is set to Success.
    function withdrawRaisedToken() external {
        if (FTOState != Status.Success) {
            revert FTOPairStatusError(FTOPairErrorCode.NotSuccess);
        }
        // The part confirming whether msg.sender is the address of a hook contract with a burnable function:
        if (msg.sender != hook || !hook.hasBurnable()) {
            revert Unauthorized(msg.sender);
        }

        _transferLP(msg.sender);
    }

    /// @dev Function that allows the [claimer] to claim LP tokens
    /// This function can only be called after the fundraising is completed,
    ///   liquidity has been added to the Dex pool, and the FTO status is set to Success.
    /// @param claimer The address claiming the LP tokens; the address receiving the LP tokens
    function claimLP(address claimer) external lock {
        if (FTOState != Status.Success) {
            revert FTOPairStatusError(FTOPairErrorCode.NotSuccess);
        }
        /**
         * [claimer] must satisfy the following conditions:
         * 1. A depositor can be a [claimer].
         * 2. A launchedTokenProvider that does not use a custom hook can be a [claimer].
         * 3. If a custom hook is used but the hook does not have a burnable function, it can be a [claimer].
         */
        if (
            raisedTokenDeposit[claimer] == 0 &&
            (claimer != launchedTokenProvider || hook.hasBurnable())
        ) {
            revert Unauthorized(claimer);
        }

        _transferLP(claimer);
    }

    /// @dev A function that calculates the amount of LP tokens [to] can claim and transfers that amount to [to].
    /// @param to The address of the claimer
    function _transferLP(address to) private {
        /**
         * lpAmount is the amount of LP tokens the claimer[to] can claim.
         * lpAmount includes the LP tokens the claimer[to] has already claimed.
         * Therefore, the condition lpAmount > claimedAmount must be satisfied.
         */
        uint256 lpAmount = _calculateLPAmount(to);
        uint256 claimedAmount = claimedLp[to];

        if (lpAmount <= claimedAmount) {
            revert NoClaimAmountRemaining(lpAmount, claimedAmount);
        }

        // claimableAmount is the actual amount of LP tokens being claimed by the claimer[to].
        uint256 claimableAmount = lpAmount - claimedAmount;
        // At this point, the amount of LP tokens claimed by the claimer[to] becomes lpAmount.
        claimedLp[to] = lpAmount;

        // Update the totalClaimedLp
        totalClaimedLp += claimableAmount;

        TransferHelper.safeTransfer(lpToken, to, claimableAmount);
        emit ClaimLP(to, claimableAmount);
    }

    /// @dev Calculates the amount of LP tokens the [claimer] can claim at the current time.
    /// This value is calculated by subtracting the already claimed amount from lpAmount.
    /// @return The amount of LP tokens the claimer can claim at the current time.
    function claimableLP(address claimer) external view returns (uint256) {
        if (FTOState != Status.Success) {
            revert FTOPairStatusError(FTOPairErrorCode.NotSuccess);
        }

        uint256 lpAmount = _calculateLPAmount(claimer);
        return lpAmount - claimedLp[claimer];
    }

    /// @dev Calculates the total amount of LP tokens the [claimer] can claim from the FTOPair.
    /// This value includes the amount already claimed.
    /// @param caller address of claimer
    /// @return lpAmount The total amount of LP tokens the claimer can claim.
    function _calculateLPAmount(
        address caller
    ) internal view returns (uint256 lpAmount) {
        /**
         * Calculates the total accumulated amount of LP tokens up to the current time.
         * totalClaimedLp: The total amount of LP tokens already claimed.
         * The reason for calculating cumulativeLP each time is that the balance of address(this)
         *  may change as vested LP tokens are released and sent back to the FTOPair.
         */
        uint256 cumulativeLP = IERC20(lpToken).balanceOf(address(this)) +
            totalClaimedLp;
        /**
         * lpAmount = cumulativeLP / 2;
         * If the claimer is the launchedTokenProvider, they can claim 50% of the total LP tokens.
         * The launchedTokenProvider holds a 50% share.
         */
        lpAmount = cumulativeLP >> 1;

        /**
         * If the claimer is a common depositor and not the launchedTokenProvider,
         *  they can claim their proportional share of the remaining 50% of LP tokens.
         * The depositor's share is calculated as raisedTokenDeposit[caller] / depositedRaisedToken.
         */
        if (launchedTokenProvider != caller) {
            lpAmount =
                (raisedTokenDeposit[caller] * lpAmount) /
                depositedRaisedToken;
        }
    }

    /// @dev This function claims the remaining LaunchedToken in the FTOPair after successful fundraising.
    /// The remaining LaunchedToken in the FTOPair is provided as a reward to RaisedToken depositors in the FTO.
    /// @param claimer Address of the RaisedToken depositor
    function claimLaunchedToken(address claimer) external lock {
        if (FTOState != Status.Success) {
            revert FTOPairStatusError(FTOPairErrorCode.NotSuccess);
        }

        if (raisedTokenDeposit[claimer] == 0) {
            revert NotDepositor(claimer);
        }

        if (claimedLaunchedToken[claimer]) {
            revert LaunchedTokenAlreadyClaimed(claimer);
        }

        // Calculates the amount of LaunchedToken the claimer can claim as a reward.
        uint256 amount = _calculateLaunchedTokenAmount(claimer);
        if (amount == 0) {
            revert InvalidAmount();
        }

        claimedLaunchedToken[claimer] = true;

        TransferHelper.safeTransfer(launchedToken, claimer, amount);

        emit ClaimLaunchedToken(claimer, amount);
    }

    /// @dev This function returns the amount of LaunchedToken that the [claimer] can claim.
    function claimableLaunchedToken(
        address claimer
    ) external view returns (uint256) {
        if (FTOState != Status.Success) {
            revert FTOPairStatusError(FTOPairErrorCode.NotSuccess);
        }
        uint256 amount = claimedLaunchedToken[claimer]
            ? 0
            : _calculateLaunchedTokenAmount(claimer);
        return amount;
    }

    /// @dev Calculates the amount of LaunchedToken the [claimer] can claim as a reward.
    /// If already claimed, the amount is calculated as 0.
    function _calculateLaunchedTokenAmount(
        address caller
    ) internal view returns (uint256 amount) {
        /**
         * The amount is calculated in proportion to the [claimer]'s share.
         * poolLaunchedTokenAmount is the initial amount of LaunchedToken provided as a reward in the FTO.
         */
        amount =
            (raisedTokenDeposit[caller] * poolLaunchedTokenAmount) /
            depositedRaisedToken;
    }

    /// @dev This function supplies liquidity to the Dex pool using the accumulated LaunchedToken and RaisedToken
    ///  in the FTO at the end of the fundraising period.
    /// If there are no accumulated RaisedToken at the end of the fundraising period, the FTO status becomes Failed.
    function _perform() internal {
        if (depositedRaisedToken != 0) {
            /**
             * launchAmount is the actual amount of LaunchedToken to be supplied to the Dex pool.
             * It is calculated based on launchPercent.
             */
            uint256 launchAmount = (depositedLaunchedToken * launchPercent) /
                100;
            /**
             * poolLaunchedTokenAmount is the amount of LaunchedToken remaining after being supplied to the Dex pool.
             * The remaining tokens are provided as a reward to the depositors.
             */
            poolLaunchedTokenAmount = depositedLaunchedToken - launchAmount;

            // The code section for adding liquidity to HenloDex
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

            // The code section for getting the address of the LP token received after supplying liquidity.
            address poolFactory = IHenloDexRouterV1(otherPool).factory();
            address pair = IHenloDexFactory(poolFactory).getPair(
                raisedToken,
                launchedToken
            );
            lpToken = pair;

            /**
             * _totalLP is the value of the total LP tokens excluding the fee that must be sent to the FTOFactory.
             * Transfer the LP tokens corresponding to the feePercent to the FTOFactory as a fee.
             */
            uint256 _totalLP = (liquidity * (100 - feePercent)) / 100;
            TransferHelper.safeTransfer(pair, factory, liquidity - _totalLP);

            FTOState = Status.Success;

            // Handling part for when the FTO uses a custom hook
            if (hook.hasLiquidityHookOp()) {
                /**
                 * Integration part with the Vesting Hook
                 * vestAmount is the amount of LP tokens to be vested in the hook.
                 * Approve the hook contract to transfer the calculated vestAmount.
                 */
                uint256 vestAmount = (_totalLP * percent4hook) / 100;
                IERC20(pair).approve(hook, vestAmount);
                IYexFTOHook(hook).liquidityHookOp(pair, vestAmount);
            }
        } else {
            FTOState = Status.Failed;
        }
        emit Perform(uint(FTOState));
    }

    /// @dev Check if the fundraising end time has passed and if the FTO status is not Paused.
    /// This function checks whether the _perform function can be executed.
    function _isUpkeepNeeded() internal view returns (bool) {
        return block.timestamp > endTime && FTOState == Status.Processing;
    }

    /// @dev Returns the result of the _isUpkeepNeeded() function.
    /// Off-chain, this function is used to determine whether to call the [performUpkeep] function.
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

    /// @dev This is an external function that executes the _perform() function.
    /// Within the function, it performs an additional check of _isUpkeepNeeded().
    /// If _isUpkeepNeeded() returns true, it executes the _perform() function.
    /// This function is a permissionless function that anyone can execute.
    function performUpkeep(bytes calldata) external override {
        if (!_isUpkeepNeeded()) {
            revert FTOPairStatusError(FTOPairErrorCode.NotFinishedOrPaused);
        }
        _perform();
    }

    /// @dev Returns the addresses of the three tokens managed by the FTOPair.
    /// @return A struct containing the addresses of the raised token, launched token, and LP token
    function getFtoPairTokenInfo()
        external
        view
        override
        returns (FtoPairTokenInfo memory)
    {
        return
            FtoPairTokenInfo({
                raisedToken: raisedToken,
                launchedToken: launchedToken,
                lpToken: lpToken
            });
    }

    /// @dev Changes the status of the FTO to Paused.
    /// This function can only be called by the FTOFactory.
    function pause() external override {
        if (msg.sender != factory) {
            revert Unauthorized(msg.sender);
        }

        if (FTOState != Status.Processing) {
            revert FTOPairStatusError(FTOPairErrorCode.NotInProcessing);
        }

        FTOState = Status.Paused;
        emit Paused(block.timestamp);
    }

    /// @dev Resumes the status of the FTO that was Paused.
    /// This function can only be called by the FTOFactory.
    function resume() external override {
        if (msg.sender != factory) {
            revert Unauthorized(msg.sender);
        }

        if (FTOState != Status.Paused) {
            revert FTOPairStatusError(FTOPairErrorCode.NotPaused);
        }

        FTOState = Status.Processing;
        emit Resumed(block.timestamp);
    }

    function withdrawFee(address feeTo) external override {}
}
