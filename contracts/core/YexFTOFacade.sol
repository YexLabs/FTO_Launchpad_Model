// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/Ownable.sol";
import "../interfaces/IYexFTOFacade.sol";
import "../interfaces/IYexFTOPair.sol";
import "../libraries/YexFTOLibrary.sol";
import "../libraries/TransferHelper.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

/// @title YexFTOFacade
/// @notice The contract that directly interacts with the users.
contract YexFTOFacade is IYexFTOFacade, Ownable {
    address public immutable override factory;

    constructor(address _factory) {
        factory = _factory;
    }

    /// @notice This function returns the FTOPair address derived from the raisedToken and launchedToken.
    function getFTOPair(
        address raisedToken,
        address launchedToken
    ) public view returns (address pair) {
        pair = YexFTOLibrary.pairFor(factory, raisedToken, launchedToken);
    }

    /// @notice This function returns the address of the token launcher or the hook for the FTO.
    /// @param raisedToken the address of Raised Token
    /// @param launchedToken the address of Launched Token
    function getFTOPairProvider(
        address raisedToken,
        address launchedToken
    ) public view returns (address provider) {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        provider = IYexFTOPair(pair).launchedTokenProvider();
    }

    /// @notice Allows you to get the fundraising status of the FTO.
    function getFTOState(
        address raisedToken,
        address launchedToken
    ) public view override returns (uint256 state) {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        state = uint256(IYexFTOPair(pair).FTOState());
    }

    /// @notice Allows you to deposit RaisedToken or LaunchedToken into the FTO.
    /// @param raisedToken the address of Raised Token
    /// @param launchedToken the address of Launched Token
    /// @param raisedTokenAmount Amount of Raised Token to be deposited
    /// @param launchedTokenAmount Amount of Launched Token to be deposited
    function deposit(
        address raisedToken,
        address launchedToken,
        uint256 raisedTokenAmount,
        uint256 launchedTokenAmount
    ) external override {
        _deposit(
            raisedToken,
            launchedToken,
            raisedTokenAmount,
            launchedTokenAmount
        );
    }

    /// @dev This function withdraws LaunchedToken from the FTO.
    /// The function caller must be the token launcher or the hook.
    function withdraw(
        address raisedToken,
        address launchedToken
    ) external override {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        IYexFTOPair(pair).withdraw(msg.sender);
    }

    /// @notice Claim the LP tokens from the FTO corresponding to your share.
    function claimLP(
        address raisedToken,
        address launchedToken
    ) external override {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        IYexFTOPair(pair).claimLP(msg.sender);
    }

    /// @notice Withdraw your RaisedToken that was deposited in the FTO.
    /// @dev This function will only succeed and not revert if the FTO status is Paused.
    function refundRaisedToken(
        address raisedToken,
        address launchedToken
    ) external override {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        IYexFTOPair(pair).refundRaisedToken(msg.sender);
    }

    /// @notice Returns the amount of LP tokens you can claim from the FTO.
    function claimableLP(
        address raisedToken,
        address launchedToken
    ) external view override returns (uint256) {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        return IYexFTOPair(pair).claimableLP(msg.sender);
    }

    /// @dev Deposit RaisedToken and LaunchedToken by calling the depositRaisedToken()
    ///  and depositLaunchedToken() functions of the FTOPair.
    /// First, transfer the RaisedToken to the FTOPair, then call the depositRaisedToken() function.
    /// First, transfer the LaunchedToken to the FTOPair, then call the depositLaunchedToken() function.
    /// @param raisedToken the address of Raised Token
    /// @param launchedToken the address of Launched Token
    /// @param raisedTokenAmount Amount of Raised Token to be deposited
    /// @param launchedTokenAmount Amount of Launched Token to be deposited
    function _deposit(
        address raisedToken,
        address launchedToken,
        uint256 raisedTokenAmount,
        uint256 launchedTokenAmount
    ) internal {
        require(
            raisedTokenAmount > 0 || launchedTokenAmount > 0,
            "INSUFFICIENT_INPUT_AMOUNT"
        );
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        // transfer amount to pair
        if (raisedTokenAmount > 0) {
            TransferHelper.safeTransferFrom(
                raisedToken,
                msg.sender,
                pair,
                raisedTokenAmount
            );
            IYexFTOPair(pair).depositRaisedToken(msg.sender, raisedTokenAmount);
        }
        if (launchedTokenAmount > 0) {
            TransferHelper.safeTransferFrom(
                launchedToken,
                msg.sender,
                pair,
                launchedTokenAmount
            );
            IYexFTOPair(pair).depositLaunchedToken(
                msg.sender,
                launchedTokenAmount
            );
        }
    }
}
