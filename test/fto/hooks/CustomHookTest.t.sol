// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "./FTOHookTest.t.sol";
import {HookMiner} from "../../../contracts/libraries/HookMiner.sol";
import {CustomHook} from "../../../contracts/hook/CustomHook.sol";
import {IYexFTOPairV2} from "../../../contracts/interfaces/IYexFTOPairV2.sol";

contract CustomHookTest is FTOHookTest {
    CustomHook public hook;
    address public hookAddress;

    address public constant RECEIVER = address(0x1211);
    uint256 public constant AMOUNT = 1000000000 ether;
    function _createHooks() private {
        uint160 flags = uint160(
            YexFTOHook.EXECUTE_FLAG |
                YexFTOHook.LIQUIDITY_HOOK_OP_FLAG |
                YexFTOHook.BURNABLE_FLAG
        );

        (address hookAddress_, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(CustomHook).creationCode,
            abi.encode(address(yexFTOFactory))
        );
        hook = new CustomHook{salt: salt}(address(yexFTOFactory));
        hookAddress = hookAddress_;

        yexFTOFactory.addWhiteList(hookAddress);
    }

    function _createFTOPair() private {
        uint256 raisingCycle = 100;
        uint256 startTimestamp = block.timestamp + raisingCycle + 100;
        uint64 durationSeconds = 10000;
        uint256 hookPercent = 50;

        bytes memory hookParams = abi.encode(
            uint64(startTimestamp),
            durationSeconds,
            RECEIVER
        );

        bytes memory data = abi.encode(hookPercent, hookParams);

        FTOParams memory params = FTOParams({
            NAME: "Test Token",
            SYMBOL: "TST",
            AMOUNT: AMOUNT,
            LAUNCHED_TOKEN_PERCENT: 50,
            RAISING_CYCLE: raisingCycle,
            DATA: data
        });

        _createFTO(hookAddress, address(usdt), address(henloDexRouter), params);
    }

    function setUp() public {
        _deployContracts();
        _createHooks();
        _createFTOPair();
    }

    function test_DeployContracts() public view {
        assertTrue(address(usdt) != address(0));
        assertTrue(address(yexFTOFactory) != address(0));
        assertTrue(address(yexFTOFacade) != address(0));
        assertTrue(address(yexFTOPair) != address(0));
        assertTrue(address(henloDexFactory) != address(0));
        assertTrue(address(henloDexRouter) != address(0));
        assertTrue(address(hook) == hookAddress);
    }

    function test_FTOPairInfo() public view {
        address launchedToken = yexFTOPair.launchedToken();
        assertEq(
            yexFTOFactory.getFTOPairProvider(address(usdt), launchedToken),
            hookAddress
        );

        assertEq(
            yexFTOFacade.getFTOPairProvider(address(usdt), launchedToken),
            hookAddress
        );

        assertEq(
            yexFTOFacade.getFTOPair(address(usdt), launchedToken),
            address(yexFTOPair)
        );

        assertEq(
            uint256(yexFTOFacade.getFTOState(address(usdt), launchedToken)),
            uint256(IYexFTOPairV2.Status.Processing)
        );

        assertEq(yexFTOPair.depositedLaunchedToken(), AMOUNT);
    }
}
