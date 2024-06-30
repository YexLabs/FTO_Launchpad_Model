// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../interfaces/IYexFTOHook.sol";
import "../interfaces/IYexFTOPair.sol";
import "../interfaces/IHenloDexPair.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./../libraries/TransferHelper.sol";

abstract contract VestingHook is IYexFTOHook, AccessControl {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    event ERC20Released(address indexed token, uint256 amount);

    address public ftoFactory;
    mapping(address => uint256) private _erc20Released;

    struct VestingInfo {
        address beneficiaryAddress;
        uint64 startTimestamp;
        uint64 durationSeconds;
        address lpToken;
    }

    mapping(address => VestingInfo) public getPair;

    constructor(address _ftoFactory) {
        ftoFactory = _ftoFactory;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(FACTORY_ROLE, _ftoFactory);
    }

    function execute(
        address ftoPair,
        bytes calldata data
    ) external override onlyRole(FACTORY_ROLE) {
        require(
            getPair[ftoPair].beneficiaryAddress == address(0),
            "pair have added."
        );

        (
            address beneficiaryAddress,
            uint64 startTimestamp,
            uint64 durationSeconds
        ) = abi.decode(data, (address, uint64, uint64));

        require(startTimestamp > 0, "vesting time cannot less than 0");

        getPair[ftoPair] = VestingInfo(
            beneficiaryAddress,
            startTimestamp,
            durationSeconds,
            address(0)
        );
    }

    function afterAddLiquidity(
        address ftoPair,
        address lpToken,
        uint256 lpAmount
    ) external override {
        TransferHelper.safeTransferFrom(
            lpToken,
            ftoPair,
            address(this),
            lpAmount
        );
        getPair[ftoPair].lpToken = lpToken;
    }

    function claimLP(address ftoPair, address lpToken) external override {
        _claimLPAndBurn(ftoPair, lpToken);
    }

    // used for claim and burn, do we burn lp or burn launchedToken?
    function _claimLPAndBurn(address ftoPair, address lpToken) internal {
        uint256 lpAmount = IYexFTOPair(ftoPair).claimableLP(address(this));
        require(lpAmount > 0, "claimableLP cannot less than 0");
        IYexFTOPair(ftoPair).claimLP(address(this));

        TransferHelper.safeTransfer(lpToken, lpToken, lpAmount);

        // remove liquidity
        (uint amount0, uint amount1) = IHenloDexPair(lpToken).burn(
            address(this)
        );

        address raisedToken = IYexFTOPair(ftoPair).raisedToken();
        address launchedToken = IYexFTOPair(ftoPair).launchedToken();

        (address token0, ) = raisedToken < launchedToken
            ? (raisedToken, launchedToken)
            : (launchedToken, raisedToken);

        (, uint256 launchedAmount) = raisedToken == token0
            ? (amount0, amount1)
            : (amount1, amount0);

        ERC20Burnable(launchedToken).burn(launchedAmount);
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
}
