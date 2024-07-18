// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "../../interfaces/IERC20.sol"; //import IERC20;
import "../../interfaces/IYexFTOFactoryV2.sol";
import "../../interfaces/IYexFTOPairV2.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Incentive is AccessControl {
    address public ftoFactory;
    address public hpot;
    address public vault;
    uint256 public rewardAmount;
    uint256 public totalReward;

    event Reward(address user, uint256 amount);

    error InvalidState();

    constructor(address _ftoFactory, address _hpot, address _vault) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        ftoFactory = _ftoFactory;
        hpot = _hpot;
        vault = _vault;
    }

    /// @notice Setup HPOT reward amount.
    /// Only admin can call this function.
    /// @param _rewardAmount reward amount
    function setRewardAmount(
        uint256 _rewardAmount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardAmount = _rewardAmount;
    }

    /// @notice Setup HPOT vault address.
    /// Only admin can call this function.
    /// @param _vault vault address
    function setVault(address _vault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        vault = _vault;
    }

    /// @notice Returns if the FTOPair can perform.
    function performable(
        address raisedToken,
        address launchedToken
    ) external view returns (bool) {
        address ftoPair = _getFTOPair(raisedToken, launchedToken);
        (bool _isSuccess, ) = IYexFTOPairV2(ftoPair).checkUpkeep("0x");
        return _isSuccess;
    }

    function _getFTOPair(
        address raisedToken,
        address launchedToken
    ) internal view returns (address ftoPair) {
        ftoPair = IYexFTOFactoryV2(ftoFactory).getPair(
            raisedToken,
            launchedToken
        );
    }

    /// @notice Perform the FTOPair and receive reward from vault.
    /// @dev This function is used to perform the FTOPair and get HPOT reward from vault.
    /// Revert when perfrom failed.
    /// @param raisedToken Token address for investment in FTO fundraising
    /// @param launchedToken Token address for investment in FTO fundraising
    function perform(address raisedToken, address launchedToken) external {
        address ftoPair = _getFTOPair(raisedToken, launchedToken);
        (bool _isSuccess, ) = IYexFTOPairV2(ftoPair).checkUpkeep("0x");
        require(_isSuccess, "FTO pair have not finished.");

        IYexFTOPairV2(ftoPair).performUpkeep("0x");

        IERC20 token = IERC20(hpot);
        require(
            token.allowance(vault, address(this)) >= rewardAmount,
            "Need Approve ERC20 token"
        );
        token.transferFrom(vault, msg.sender, rewardAmount);

        totalReward += rewardAmount;

        emit Reward(msg.sender, rewardAmount);
    }
}
