// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./../libraries/TransferHelper.sol";
import "./NormalHook.sol";
import "./Lock.sol";

abstract contract VestingHook is NormalHook, Lock {
    event ERC20Released(address indexed token, uint256 amount);

    mapping(address => uint256) private _erc20Released;

    struct VestingHookParam {
        uint64 startTimestamp;
        uint64 durationSeconds;
    }

    struct VestingInfo {
        address beneficiaryAddress;
        uint64 startTimestamp;
        uint64 durationSeconds;
        address lpToken;
    }
    mapping(address => VestingInfo) public getPair;

    modifier onlyFTOPair() {
        require(
            getPair[msg.sender].beneficiaryAddress != address(0),
            "FTOPair not added or not authorized"
        );
        _;
    }

    function createFTO(
        address raisedToken,
        string calldata name,
        string calldata symbol,
        uint256 amount,
        uint256 launchedTokenPercent,
        address poolHandler,
        uint256 raisingCycle,
        bytes calldata data
    ) public virtual override lockFunction {
        super.createFTO(
            raisedToken,
            name,
            symbol,
            amount,
            launchedTokenPercent,
            poolHandler,
            raisingCycle,
            data
        );
    }

    function execute(
        bytes calldata data
    ) public virtual override onlyWhenLocked {
        VestingHookParam memory params = abi.decode(data, (VestingHookParam));

        _setVestingHookParam(params);
    }

    function _setVestingHookParam(VestingHookParam memory params) internal {
        require(params.startTimestamp > 0, "vesting time cannot less than 0");

        getPair[msg.sender] = VestingInfo(
            msg.sender,
            params.startTimestamp,
            params.durationSeconds,
            address(0)
        );
    }

    function liquidityHookOp(
        address lpToken,
        uint256 lpAmount
    ) public virtual override onlyFTOPair {
        getPair[msg.sender].lpToken = lpToken;
        TransferHelper.safeTransferFrom(
            lpToken,
            msg.sender,
            address(this),
            lpAmount
        );
    }

    /**
     * @dev Getter for the beneficiary address.
     */
    function beneficiary(
        address ftoPair
    ) public view virtual returns (address) {
        return getPair[ftoPair].beneficiaryAddress;
    }

    /**
     * @dev Getter for the start timestamp.
     */
    function start(address ftoPair) public view virtual returns (uint256) {
        return getPair[ftoPair].startTimestamp;
    }

    /**
     * @dev Getter for the vesting duration.
     */
    function duration(address ftoPair) public view virtual returns (uint256) {
        return getPair[ftoPair].durationSeconds;
    }

    /**
     * @dev Amount of token already released
     */
    function released(address ftoPair) public view virtual returns (uint256) {
        return _erc20Released[getPair[ftoPair].lpToken];
    }

    /**
     * @dev Getter for the amount of releasable `token` tokens. `token` should be the address of an
     * IERC20 contract.
     */
    function releasable(address ftoPair) public view virtual returns (uint256) {
        return
            vestedAmount(ftoPair, uint64(block.timestamp)) - released(ftoPair);
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     */
    function release(address ftoPair) public virtual {
        uint256 amount = releasable(ftoPair);
        _erc20Released[getPair[ftoPair].lpToken] += amount;
        emit ERC20Released(getPair[ftoPair].lpToken, amount);
        TransferHelper.safeTransfer(
            getPair[ftoPair].lpToken,
            beneficiary(ftoPair),
            amount
        );
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(
        address ftoPair,
        uint64 timestamp
    ) public view virtual returns (uint256) {
        return
            _vestingSchedule(
                ftoPair,
                IERC20(getPair[ftoPair].lpToken).balanceOf(address(this)) +
                    released(ftoPair),
                timestamp
            );
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(
        address ftoPair,
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view virtual returns (uint256) {
        if (timestamp < start(ftoPair)) {
            return 0;
        } else if (timestamp > start(ftoPair) + duration(ftoPair)) {
            return totalAllocation;
        } else {
            return
                (totalAllocation * (timestamp - start(ftoPair))) /
                duration(ftoPair);
        }
    }

    function getFlags() public pure virtual override returns (YexFTOHook.Flags memory) {
        return YexFTOHook.Flags({
            execute: true,
            liquidityHookOp: true,
            burnable: false
        });
    }
}
