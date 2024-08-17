// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./YexFTOPairV2.sol";
import "./YexFTOLaunchToken.sol";
import "../interfaces/IYexFTOFactoryV2.sol";

/// @title Factory that generates FTOPair
/// @notice Creating Launch Token and FTO launchpad.
contract YexFTOFactoryV2 is IYexFTOFactoryV2, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;

    address[] public allPairs;
    /// @dev List of RaisedToken addresses allowed for fundraising in the FTO Launchpad
    address[] public raisedTokens;

    bytes32 public constant INIT_CODE_PAIR_HASH =
        keccak256(abi.encodePacked(type(YexFTOPairV2).creationCode));

    mapping(address => EnumerableSet.AddressSet) private eventParticipants;

    /// @dev [LaunchedToken][RaisedToken] => FTOPair address
    mapping(address => mapping(address => address)) public getPair;
    mapping(address => bool) public isRaisedToken;

    event EventAdded(address depositer, address ftoPair);
    event EventRemoved(address depositer, address ftoPair);

    error NotParticipateInThisFTOPair();
    error RaisedTokenStillRemaining();
    error FTOPairIsInvalid();
    error NotAllowedRaisedToken();
    error IdenticalAddress(address launchedToken);
    error YexFTOPairExists(address token0, address token1);
    error CreatePairFailed();
    error TokenAddressIsZero();
    error FeeToAddressIsZero();
    error LpTokenAddressIsZero();

    /// @dev If a depositor participates in the FTO fundraising, add the FTOPair address to the eventParticipants[depositor] array.
    /// This function is called by YexFTOPair contract after the depositor deposits RaisedToken in the FTOPair.
    /// @param depositor Address of participant in the FTO fundraising
    /// @param ftoPair Address of FTOPair
    function addEvent(
        address depositor,
        address ftoPair,
        address raisedToken,
        address launchedToken
    ) external override {
        (address token0, address token1) = raisedToken < launchedToken
            ? (raisedToken, launchedToken)
            : (launchedToken, raisedToken);
        if (getPair[token0][token1] != ftoPair) {
            revert FTOPairIsInvalid();
        }

        if (IYexFTOPairV2(ftoPair).raisedTokenDeposit(depositor) == 0) {
            revert NotParticipateInThisFTOPair();
        }

        eventParticipants[depositor].add(ftoPair);

        emit EventAdded(depositor, ftoPair);
    }

    /// @dev If a depositor remove from the FTO fundraising, remove the FTOPair address from the eventParticipants[depositor] array.
    /// This function is called by YexFTOPair contract after the depositor refund RaisedToken in the FTOPair.
    /// @param depositor Address of participant in the FTO fundraising
    /// @param ftoPair Address of FTOPair
    function removeEvent(address depositor, address ftoPair) external override {
        if (IYexFTOPairV2(ftoPair).raisedTokenDeposit(depositor) > 0) {
            revert RaisedTokenStillRemaining();
        }

        if (!eventParticipants[depositor].remove(ftoPair)) {
            revert NotParticipateInThisFTOPair();
        }

        emit EventRemoved(depositor, ftoPair);
    }

    /// @notice Returns the list of FTOPairs that the depositor has participated in.
    function events(
        address depositor
    ) external view override returns (address[] memory pairs) {
        return eventParticipants[depositor].values();
    }

    /// @notice Add raisedToken
    /// @dev This function add a new token used for investment.
    /// Only the factory owner can call this function.
    /// @param _raisedToken Token address for investment in FTO fundraising
    function addRaisedToken(address _raisedToken) external payable onlyOwner {
        if (!isRaisedToken[_raisedToken]) {
            raisedTokens.push(_raisedToken);
            isRaisedToken[_raisedToken] = true;
            emit RaisedTokenAdded(_raisedToken);
        }
    }

    /// @notice Remove raisedToken
    /// @dev This function remove a token used for investment.
    /// Only the factory owner can call this function.
    /// @param _raisedToken Token address for investment in FTO fundraising
    function removeRaisedToken(
        address _raisedToken
    ) external payable onlyOwner {
        if (isRaisedToken[_raisedToken]) {
            isRaisedToken[_raisedToken] = false;
            emit RaisedTokenRemoved(_raisedToken);
        }
    }

    /// @notice Creates Launch Token and FTOPair
    /// @dev This function can be called from the Token Launcher's address or Hook contract.
    /// Deploy the LaunchedToken, create the FTOPair, mint LaunchedToken on FTOPair and initialize the FTOPair.
    /// @param raisedToken Token address for investment in FTO fundraising
    /// @param name The name of the LaunchedToken
    /// @param symbol The symbol of the LaunchedToken
    /// @param _amount The totalSupply of LaunchedToken, which is initially minted in its entirety
    /// @param launchedTokenPercent The proportion of LaunchedToken added to the AMM Pool
    /// @param poolHandler The router address of DEX
    /// @param raisingCycle Fundraising period (in seconds)
    /// @param data Data to be passed to the Hook; empty if LaunchPad does not use a hook
    /// @return pair The address of the newly created FTO Pair
    function createFTO(
        address raisedToken,
        string calldata name,
        string calldata symbol,
        uint256 _amount,
        uint256 launchedTokenPercent,
        address poolHandler,
        uint256 raisingCycle,
        bytes calldata data
    ) external override returns (address pair) {
        /**
         * YexFTOFactory obtains the ROLE to mint LaunchedToken.
         * msg.sender(Token launcher or hook) obtains the ROLE to burn LaunchedToken in his own account.
         */
        YexFTOLaunchToken _launchedToken = new YexFTOLaunchToken(
            name,
            symbol,
            msg.sender
        );

        address launchedToken = address(_launchedToken);

        /**
         * Deploy FTOPair and mint LaunchedToken on FTOPair
         * Initialize FTOPair
         */
        pair = _createPair(
            raisedToken,
            launchedToken,
            msg.sender,
            launchedTokenPercent,
            _amount,
            poolHandler,
            raisingCycle,
            data
        );
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    function allRaisedTokens() external view returns (address[] memory) {
        return raisedTokens;
    }

    /// @dev Deploy the FTOPair using create2
    /// and mint LaunchedToken on FTOPair
    /// and call the [initialize] function of FTOPair to initialize it.
    /// This function is called after the LaunchedToken is deployed.
    /// @param raisedToken Token address for investment in FTO fundraising
    /// @param launchedToken The address of LaunchedToken
    /// @param launchedTokenProvider When not using a custom hook, the address of the Token Launcher; when using a custom hook, the address of the hook contract
    /// @param launchedTokenPercent The proportion of LaunchedToken added to the DEX Pool
    /// @param launchedTokenSupply The totalSupply of LaunchedToken, which is initially minted in its entirety
    /// @param swapHandler The router address of DEX
    /// @param raisingCycle Fundraising period (in seconds)
    /// @param data Data to be passed to the Hook; empty if LaunchPad does not use a hook
    /// @return pair The address of the newly created FTO Pair
    function _createPair(
        address raisedToken,
        address launchedToken,
        address launchedTokenProvider,
        uint256 launchedTokenPercent,
        uint256 launchedTokenSupply,
        address swapHandler,
        uint256 raisingCycle,
        bytes calldata data
    ) internal returns (address pair) {
        if (raisedToken == launchedToken) {
            revert IdenticalAddress(launchedToken);
        }

        if (!isRaisedToken[raisedToken]) {
            revert NotAllowedRaisedToken();
        }

        (address token0, address token1) = raisedToken < launchedToken
            ? (raisedToken, launchedToken)
            : (launchedToken, raisedToken);

        if (token0 == address(0)) {
            revert TokenAddressIsZero();
        }

        if (getPair[token0][token1] != address(0)) {
            revert YexFTOPairExists(token0, token1);
        }

        /**
         * Deploy the FTOPair using create2
         * The FTOPair address can be calculated using raisedToken and launchedToken
         */
        bytes memory bytecode = type(YexFTOPairV2).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        if (pair == address(0)) {
            revert CreatePairFailed();
        }

        /**
         * Only FTOFactory: address(this) can mint.
         * Mint launchedTokenSupply of LaunchedToken to FTOPair
         */
        YexFTOLaunchToken(launchedToken).mint(pair, launchedTokenSupply);

        /**
         * Set the parameter values in the FTOPair contract.
         * If using a CustomHook, send [data] to the hook in the FTOPair's [initialize].
         */
        YexFTOPairV2(pair).initialize(
            raisedToken,
            launchedToken,
            launchedTokenProvider,
            launchedTokenPercent,
            swapHandler,
            raisingCycle,
            data
        );
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;

        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);

        _afterCreatePair(pair);
    }

    function _afterCreatePair(address pair) internal {
        // _registerAndPredictID(pair);
    }

    /// @dev This function pauses the fundraising of the FTOPair.
    /// Only the factory owner can call this function.
    /// It can only be paused if the FTOPair status is Processing.
    /// After calling this function, depositors can withdraw their RaisedToken invested in the FTOPair.
    /// After calling this function, the token provider can withdraw all the LaunchedToken from the FTOPair.
    function pause(
        address raisedToken,
        address launchedToken
    ) external payable override onlyOwner {
        address pair = getPair[raisedToken][launchedToken];
        IYexFTOPairV2(pair).pause();
    }

    /// @dev This function resumes the fundraising status of the FTOPair that was paused.
    /// Only the factory owner can call this function.
    /// It can only be resumed if the FTOPair status is Paused.
    function resume(
        address raisedToken,
        address launchedToken
    ) external payable override onlyOwner {
        address pair = getPair[raisedToken][launchedToken];
        IYexFTOPairV2(pair).resume();
    }

    function getFTOPairProvider(
        address raisedToken,
        address launchedToken
    ) public view returns (address provider) {
        address pair = getPair[raisedToken][launchedToken];
        provider = IYexFTOPairV2(pair).launchedTokenProvider();
    }

    /// @notice Withdraws the accumulated LPToken received as a fee from the FTOPair.
    /// @dev This function withdraws the LPToken received as a fee from the FTOPair after a successful fundraising in the FTOPair Launchpad.
    /// Only the factory owner can call this function, and the ftoPair must be specified with [raisedToken, launchedToken].
    function withdrawFee(
        address raisedToken,
        address launchedToken,
        address feeTo
    ) external payable onlyOwner {
        if (feeTo == address(0)) {
            revert FeeToAddressIsZero();
        }

        address pair = getPair[raisedToken][launchedToken];
        address lpToken = YexFTOPairV2(pair).lpToken();

        if (lpToken == address(0)) {
            revert LpTokenAddressIsZero();
        }

        uint256 fee = IERC20(lpToken).balanceOf(address(this));
        if (fee > 0) {
            TransferHelper.safeTransfer(lpToken, feeTo, fee);
        }
    }
}
