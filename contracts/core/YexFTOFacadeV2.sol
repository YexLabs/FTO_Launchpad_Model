// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/Ownable.sol";
import "../interfaces/IYexFTOFacadeV2.sol";
import "../interfaces/IYexFTOPairV2.sol";
import "../libraries/YexFTOLibrary.sol";
import "../libraries/TransferHelper.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

/// @title YexFTOFacade
/// @notice The contract that directly interacts with the users.
contract YexFTOFacadeV2 is IYexFTOFacadeV2, Ownable {
    address public immutable override factory;

    error InvalidRaisedTokenAmount();
    error FactoryError();

    constructor(address _factory) {
        if (_factory == address(0)) {
            revert FactoryError();
        }
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
        provider = IYexFTOPairV2(pair).launchedTokenProvider();
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
        state = uint256(IYexFTOPairV2(pair).FTOState());
    }

    /// @notice Allows you to deposit RaisedToken into the FTO.
    /// @param raisedToken the address of Raised Token
    /// @param launchedToken the address of Launched Token
    /// @param raisedTokenAmount Amount of Raised Token to be deposited
    function deposit(
        address raisedToken,
        address launchedToken,
        uint256 raisedTokenAmount
    ) external override {
        _deposit(raisedToken, launchedToken, raisedTokenAmount);
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
        IYexFTOPairV2(pair).claimLP(msg.sender);
    }

    /// @notice Claim the LaunchedToken allocated to you as a reward.
    function claimLaunchedToken(
        address raisedToken,
        address launchedToken
    ) external override {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        IYexFTOPairV2(pair).claimLaunchedToken(msg.sender);
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
        return IYexFTOPairV2(pair).claimableLP(msg.sender);
    }

    /// @notice Returns the amount of LaunchedToken allocated to you as a reward that you can claim from the FTO.
    function claimableLaunchedToken(
        address raisedToken,
        address launchedToken
    ) external view override returns (uint256) {
        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );
        return IYexFTOPairV2(pair).claimableLaunchedToken(msg.sender);
    }

    /// @dev Deposit RaisedToken by calling the depositRaisedToken() function of the FTOPair
    /// First, transfer the RaisedToken to the FTOPair, then call the depositRaisedToken() function.
    /// @param raisedToken the address of Raised Token
    /// @param launchedToken the address of Launched Token
    /// @param raisedTokenAmount Amount of Raised Token to be deposited
    function _deposit(
        address raisedToken,
        address launchedToken,
        uint256 raisedTokenAmount
    ) internal {
        if (raisedTokenAmount == 0) {
            revert InvalidRaisedTokenAmount();
        }

        address pair = YexFTOLibrary.pairFor(
            factory,
            raisedToken,
            launchedToken
        );

        // Transfer raisedTokenAmount to pair
        TransferHelper.safeTransferFrom(
            raisedToken,
            msg.sender,
            pair,
            raisedTokenAmount
        );
        IYexFTOPairV2(pair).depositRaisedToken(msg.sender, raisedTokenAmount);
    }
}
