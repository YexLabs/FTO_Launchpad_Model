// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "./../interfaces/IYexFTOHook.sol";
import "./../interfaces/IUniswapV2Pair.sol";
import "./../interfaces/IYexFTOPair.sol";
import "./../libraries/TransferHelper.sol";
import "./../libraries/AccessControl.sol";
import "./../core/YexFTOFactory.sol";

contract CustomHook is IYexFTOHook, AccessControl {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    bytes32 public constant PAIR_ROLE = keccak256("PAIR_ROLE");

    address public factory;
    address public ftoPair;
    address public lpToken;

    uint256 public vestingPercentage;
    uint256 public vestingPeriod;
    uint256 public lastVestingTime;

    event VestedLPReleased(uint256 amount);

    constructor(address yexFTOFactory_, uint256 initialVestingPercentage_, uint256 initialVestingPeriod_) {
        require(initialVestingPercentage_ <= 10000, "Percentage must be <= 10000");
        require(initialVestingPeriod_ > 0, "Vesting period must be greater than 0");

        factory = yexFTOFactory_;
        vestingPercentage = initialVestingPercentage_;
        vestingPeriod = initialVestingPeriod_;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(FACTORY_ROLE, yexFTOFactory_);
    }

    function setVestingPercentage(uint256 newVestingPercentage_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newVestingPercentage_ <= 10000, "Percentage must be <= 10000");
        vestingPercentage = newVestingPercentage_;
    }

    function setVestingPeriod(uint256 newVestingPeriod_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newVestingPeriod_ > 0, "Vesting period must be greater than 0");
        vestingPeriod = newVestingPeriod_;
    }

    function setFTOPair(address pair_) external override onlyRole(FACTORY_ROLE) {
        ftoPair = pair_;
        _setupRole(PAIR_ROLE, pair_);
    }
    
    function beforeAddLiquidity(address, uint256) external view override onlyRole(PAIR_ROLE) returns (bytes4) {
        return CustomHook.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(address lp, uint256 lpAmount) external override onlyRole(PAIR_ROLE) returns (uint256, uint256) {
        uint256 amountToVesting = (lpAmount * vestingPercentage) / 10000;
        uint256 remainingLpAmount = lpAmount - amountToVesting;
        remainingLpAmount = remainingLpAmount >> 1;

        TransferHelper.safeTransferFrom(lp, ftoPair, address(this), amountToVesting);

        lastVestingTime = block.timestamp;
        lpToken = lp;

        return (remainingLpAmount, remainingLpAmount);
    }

    function claimProjectLP(uint256 lpAmount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(lpAmount > 0, "LP amount must be greater than zero");
        IYexFTOPair(ftoPair).claimLP(address(this), lpAmount);

        TransferHelper.safeTransfer(lpToken, lpToken, lpAmount);
        (uint amount0, uint amount1) = IUniswapV2Pair(lpToken).burn(address(this));

        address raisedToken = IYexFTOPair(ftoPair).raisedToken();
        address launchedToken = IYexFTOPair(ftoPair).launchedToken();
        
        (address token0,) = raisedToken < launchedToken
            ? (raisedToken, launchedToken)
            : (launchedToken, raisedToken);

        (, uint256 launchedAmount) = raisedToken == token0 ? (amount0, amount1) : (amount1, amount0);

        ERC20Mintable(launchedToken).burn(launchedAmount);
    }

    function releaseVestedLP() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(block.timestamp >= lastVestingTime + vestingPeriod, "Vesting period has not yet elapsed");

        uint256 amountToVest = IERC20(lpToken).balanceOf(address(this));
        require(amountToVest > 0, "No LP tokens to vest");

        TransferHelper.safeTransfer(lpToken, ftoPair, amountToVest);
        emit VestedLPReleased(amountToVest);
    }

    function tokenLaunch(
        address raisedToken,
        string calldata name,
        string calldata symbol,
        uint256 amount,
        address poolHandler,
        uint256 raisingCycle
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(raisedToken != address(0), "Invalid raisedToken address");
        require(bytes(name).length > 0, "Token name cannot be empty");
        require(bytes(symbol).length > 0, "Token symbol cannot be empty");
        require(amount > 0, "Amount must be greater than 0");
        require(poolHandler != address(0), "Invalid poolHandler address");
        
        // temprary comment for test script
        require(raisingCycle > 0, "Raising cycle must be greater than 0");

        IYexFTOFactory(factory).createFTO(
            _msgSender(),
            raisedToken,
            name,
            symbol,
            amount,
            poolHandler,
            raisingCycle,
            address(this)
        );
    }

    function getTokenPair() public view returns(address, address) {
        require(ftoPair != address(0), "You should launch token");
        return (IYexFTOPair(ftoPair).raisedToken(), IYexFTOPair(ftoPair).launchedToken());
    }
}