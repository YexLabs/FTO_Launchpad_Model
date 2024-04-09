// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../interfaces/IYexFTOFactory.sol";
import "./YexFTOPair.sol";
import "../libraries/Ownable.sol";
import "../libraries/ERC20.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

struct RegistrationParams {
    string name;
    bytes encryptedEmail;
    address upkeepContract;
    uint32 gasLimit;
    address adminAddress;
    uint8 triggerType;
    bytes checkData;
    bytes triggerConfig;
    bytes offchainConfig;
    uint96 amount;
}

/**
 * string name = "test upkeep";
 * bytes encryptedEmail = 0x;
 * address upkeepContract = 0x...;
 * uint32 gasLimit = 500000;
 * address adminAddress = 0x....;
 * uint8 triggerType = 0;
 * bytes checkData = 0x;
 * bytes triggerConfig = 0x;
 * bytes offchainConfig = 0x;
 * uint96 amount = 1000000000000000000;
 */

interface AutomationRegistrarInterface {
    function registerUpkeep(
        RegistrationParams calldata requestParams
    ) external returns (uint256);
}

contract ERC20Mintable is ERC20, Ownable {
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract YexFTOFactory is IYexFTOFactory, Ownable {
    address[] public allPairs;
    address[] public raisedTokens;

    bytes32 public constant INIT_CODE_PAIR_HASH =
        keccak256(abi.encodePacked(type(YexFTOPair).creationCode));

    mapping(address => address[]) private eventParticipants;
    mapping(address => mapping(address => bool)) private events_map;

    mapping(address => bool) public whitelists;
    mapping(address => mapping(address => address)) public getPair;
    mapping(address => bool) public isRaisedToken;

    bool private noWhiteList;

    // for ChainLink automation
    LinkTokenInterface public i_link;
    AutomationRegistrarInterface public i_registrar;

    modifier onlyWhitelistCaller() {
        require(
            noWhiteList == true || whitelists[msg.sender] == true,
            "Caller is not a whitelist member."
        );
        _;
    }

    function setNoWhiteList(bool req) external onlyOwner {
        noWhiteList = req;
    }

    function addEvent(address depositer, address ftoPair) external override {
        require(
            IYexFTOPair(ftoPair).raisedTokenDeposit(depositer) != 0,
            "Not participate in this rasing."
        );
        if (events_map[depositer][ftoPair] == false) {
            events_map[depositer][ftoPair] = true;
            eventParticipants[depositer].push(ftoPair);
        }
    }

    function events(
        address depositer
    ) external view override returns (address[] memory pairs) {
        return eventParticipants[depositer];
    }

    function addWhiteList(address caller) external override onlyOwner {
        if (!whitelists[caller]) {
            whitelists[caller] = true;
        }
    }

    function removeWhiteList(address caller) external override onlyOwner {
        if (whitelists[caller]) {
            whitelists[caller] = false;
        }
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
        address poolHandler,
        uint256 raisingCycle
    ) external override onlyWhitelistCaller returns (address pair) {
        ERC20Mintable _launchedToken = new ERC20Mintable(name, symbol);
        uint256 amount = _amount; // mint _amount launchedToken
        address launchedToken = address(_launchedToken);

        pair = _createPair(
            raisedToken,
            launchedToken,
            msg.sender,
            poolHandler,
            raisingCycle
        );
        _launchedToken.mint(pair, amount);
        IYexFTOPair(pair).depositLaunchedToken(msg.sender, amount);
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
        address swapHandler,
        uint256 raisingCycle
    ) internal returns (address pair) {
        require(raisedToken != launchedToken, "YexFTOFactory: IDENTICAL_ADDRESSES");
        require(isRaisedToken[raisedToken], "YexFTOFactory: NOT_ALLOWED_BASE_TOKEN");

        (address token0, address token1) = raisedToken < launchedToken
            ? (raisedToken, launchedToken)
            : (launchedToken, raisedToken);

        require(token0 != address(0), "YexFTOFactory: ZERO_ADDRESS");
        require(
            getPair[token0][token1] == address(0),
            "YexFTOFactory: PAIR_EXISTS"
        ); // single check is sufficient
        bytes memory bytecode = type(YexFTOPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        YexFTOPair(pair).initialize(
            raisedToken,
            launchedToken,
            launchedTokenProvider,
            swapHandler,
            raisingCycle
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

    // function setAutomationConfig(
    //     LinkTokenInterface link,
    //     AutomationRegistrarInterface registrar
    // ) external onlyOwner {
    //     i_link = link;
    //     i_registrar = registrar;
    // }

    // function _registerAndPredictID(address pair) public {
    //     // register automation
    //     string memory name = "FTO upkeep";
    //     bytes memory encryptedEmail = bytes("0x");
    //     address upkeepContract = pair;
    //     uint32 gasLimit = 500000;
    //     address adminAddress = owner();
    //     uint8 triggerType = 0;
    //     bytes memory checkData = bytes("0x");
    //     bytes memory triggerConfig = bytes("0x");
    //     bytes memory offchainConfig = bytes("0x");
    //     uint96 amount = 1000000000000000000; // 1 Link

    //     RegistrationParams memory params = RegistrationParams(
    //         name,
    //         encryptedEmail,
    //         upkeepContract,
    //         gasLimit,
    //         adminAddress,
    //         triggerType,
    //         checkData,
    //         triggerConfig,
    //         offchainConfig,
    //         amount
    //     );

    //     // LINK must be approved for transfer - this can be done every time or once
    //     // with an infinite approval
    //     i_link.approve(address(i_registrar), params.amount);
    //     uint256 upkeepID = i_registrar.registerUpkeep(params);
    //     if (upkeepID != 0) {
    //         // DEV - Use the upkeepID however you see fit
    //     } else {
    //         revert("auto-approve disabled");
    //     }
    // }

    // bytes32 public merkleRoot;
    // function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
    //     merkleRoot = _merkleRoot;
    // }
    // function verifyMerkleProof(
    //     address caller,
    //     bytes32[] memory proof
    // ) private view returns (bool) {
    //     bytes32 node = keccak256(bytes.concat(keccak256(abi.encode(caller))));
    //     return MerkleProofUpgradeable.verify(proof, merkleRoot, node);
    // }
}
