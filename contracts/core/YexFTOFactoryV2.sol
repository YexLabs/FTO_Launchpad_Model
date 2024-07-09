// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "./WhiteList.sol";
import "./YexFTOPairV2.sol";
import "./YexFTOLaunchToken.sol";
import "../libraries/Ownable.sol";
import "../interfaces/IYexFTOFactoryV2.sol";

contract YexFTOFactoryV2 is IYexFTOFactoryV2, WhiteList {
    address[] public allPairs;
    address[] public raisedTokens;

    bytes32 public constant INIT_CODE_PAIR_HASH =
        keccak256(abi.encodePacked(type(YexFTOPairV2).creationCode));

    mapping(address => address[]) private eventParticipants;
    mapping(address => mapping(address => bool)) private events_map;

    mapping(address => mapping(address => address)) public getPair;
    mapping(address => bool) public isRaisedToken;

    function addEvent(address depositor, address ftoPair) external override {
        require(
            IYexFTOPairV2(ftoPair).raisedTokenDeposit(depositor) != 0,
            "Not participate in this rasing."
        );
        if (events_map[depositor][ftoPair] == false) {
            events_map[depositor][ftoPair] = true;
            eventParticipants[depositor].push(ftoPair);
        }
    }

    function events(
        address depositor
    ) external view override returns (address[] memory pairs) {
        return eventParticipants[depositor];
    }

    function addRaisedToken(address _raisedToken) external onlyOwner {
        if (!isRaisedToken[_raisedToken]) {
            raisedTokens.push(_raisedToken);
            isRaisedToken[_raisedToken] = true;
            emit RaisedTokenAdded(_raisedToken);
        }
    }

    function createFTO(
        address raisedToken,
        string calldata name,
        string calldata symbol,
        uint256 _amount,
        uint256 launchedTokenPercent,
        address poolHandler,
        uint256 raisingCycle,
        bytes calldata data
    ) external override onlyWhiteList returns (address pair) {
        YexFTOLaunchToken _launchedToken = new YexFTOLaunchToken(
            name,
            symbol,
            msg.sender
        );
        uint256 amount = _amount; // mint _amount launchedToken
        address launchedToken = address(_launchedToken);

        pair = _createPair(
            raisedToken,
            launchedToken,
            msg.sender,
            launchedTokenPercent,
            poolHandler,
            raisingCycle,
            data
        );

        _launchedToken.mint(pair, amount);

        IYexFTOPairV2(pair).depositLaunchedToken(msg.sender, amount);
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    function allRaisedTokens() external view returns (address[] memory) {
        return raisedTokens;
    }

    function _createPair(
        address raisedToken,
        address launchedToken,
        address launchedTokenProvider,
        uint256 launchedTokenPercent,
        address swapHandler,
        uint256 raisingCycle,
        bytes calldata data
    ) internal returns (address pair) {
        require(
            raisedToken != launchedToken,
            "YexFTOFactory: IDENTICAL_ADDRESSES"
        );
        require(
            isRaisedToken[raisedToken],
            "YexFTOFactory: NOT_ALLOWED_BASE_TOKEN"
        );

        (address token0, address token1) = raisedToken < launchedToken
            ? (raisedToken, launchedToken)
            : (launchedToken, raisedToken);

        require(token0 != address(0), "YexFTOFactory: ZERO_ADDRESS");
        require(
            getPair[token0][token1] == address(0),
            "YexFTOFactory: PAIR_EXISTS"
        ); // single check is sufficient
        bytes memory bytecode = type(YexFTOPairV2).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
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
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        // init new pair
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);

        _afterCreatePair(pair);
    }

    function _afterCreatePair(address pair) internal {
        // _registerAndPredictID(pair);
    }

    function pause(
        address raisedToken,
        address launchedToken
    ) external override onlyOwner {
        address pair = getPair[raisedToken][launchedToken];
        IYexFTOPairV2(pair).pause();
    }

    function resume(
        address raisedToken,
        address launchedToken
    ) external override onlyOwner {
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

    function withdrawFee(
        address raisedToken,
        address launchedToken,
        address feeTo
    ) external onlyOwner {
        require(feeTo != address(0), "YexFTOFactory: INVALID_FEE_TO_ADDRESS");
        address pair = getPair[raisedToken][launchedToken];
        address lpToken = YexFTOPairV2(pair).lpToken();
        require(lpToken != address(0), "YexFTOFactory: LP_TOKEN_ZERO_ADDRESS");

        uint256 fee = IERC20(lpToken).balanceOf(address(this));
        if (fee > 0) {
            TransferHelper.safeTransfer(lpToken, feeTo, fee);
        }
    }
}
