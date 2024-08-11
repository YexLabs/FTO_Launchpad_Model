// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "./FTOHookTest.t.sol";
import {HookMiner} from "../../../contracts/libraries/HookMiner.sol";
import {CustomHook} from "../../../contracts/hook/CustomHook.sol";
import {IYexFTOPairV2} from "../../../contracts/interfaces/IYexFTOPairV2.sol";
import {HenloDexPair} from "../../../contracts/core/HenloDexPair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CustomHookTest is FTOHookTest {
    CustomHook public hook;
    address public hookAddress;

    address public constant RECEIVER = address(0x1211);
    uint256 public constant AMOUNT = 1000000000 ether;
    uint256 public constant RAISING_CYCLE = 100;
    uint64 public constant DURATION_SECONDS = 10000;
    uint256 public startTimestamp;

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
        uint256 hookPercent = 50;

        startTimestamp = block.timestamp + RAISING_CYCLE + 100;

        bytes memory hookParams = abi.encode(
            uint64(startTimestamp),
            DURATION_SECONDS,
            RECEIVER
        );

        bytes memory data = abi.encode(hookPercent, hookParams);

        FTOParams memory params = FTOParams({
            NAME: "Test Token",
            SYMBOL: "TST",
            AMOUNT: AMOUNT,
            LAUNCHED_TOKEN_PERCENT: 50,
            RAISING_CYCLE: RAISING_CYCLE,
            DATA: data
        });

        _createFTO(hookAddress, address(usdt), address(henloDexRouter), params);
    }

    function _perform() private {
        uint64 newTimestamp = uint64(block.timestamp + RAISING_CYCLE + 10);

        vm.warp(newTimestamp);

        (bool upkeepNeeded, ) = yexFTOPair.checkUpkeep("");
        assertTrue(upkeepNeeded);

        yexFTOPair.performUpkeep("");
    }

    function _getLPFactors()
        private
        view
        returns (
            HenloDexPair dexPair,
            uint256 totalLp,
            uint256 zeroLp,
            uint256 ftoPairLp,
            uint256 feeLp,
            uint256 customHookLp
        )
    {
        dexPair = HenloDexPair(yexFTOPair.lpToken());

        totalLp = dexPair.totalSupply();
        zeroLp = dexPair.balanceOf(0x0000000000000000000000000000000000000000);
        ftoPairLp = dexPair.balanceOf(address(yexFTOPair));
        feeLp = dexPair.balanceOf(address(yexFTOFactory));
        customHookLp = dexPair.balanceOf(address(hook));
    }

    function setUp() public {
        _deployContracts();
        _createHooks();
        _createFTOPair();

        depositAmounts = [
            100 * 10 ** usdt.decimals(),
            200 * 10 ** usdt.decimals(),
            300 * 10 ** usdt.decimals()
        ];
        _depositRaisedTokens();
    }

    function test_ShouldDeployContracts() public view {
        assertTrue(address(usdt) != address(0));
        assertTrue(address(yexFTOFactory) != address(0));
        assertTrue(address(yexFTOFacade) != address(0));
        assertTrue(address(yexFTOPair) != address(0));
        assertTrue(address(henloDexFactory) != address(0));
        assertTrue(address(henloDexRouter) != address(0));
        assertTrue(address(hook) == hookAddress);
    }

    function test_ShouldReturnFTOPairInfo() public view {
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

    function test_ExecuteBurnableShouldBeExpectedBehavior() public view {
        assertEq(
            hook.raisedTokenReceiver(address(yexFTOPair)),
            RECEIVER,
            "Receiver should be set to the fto pair address"
        );
    }

    function test_ExecuteVestingShouldBeExpectedBehavior() public view {
        (
            address beneficiaryAddress,
            uint64 startTimestamp_,
            uint64 durationSeconds,
            address lpToken
        ) = hook.getPair(address(yexFTOPair));

        assertEq(
            beneficiaryAddress,
            address(yexFTOPair),
            "Beneficiary address should match the FTOPair address"
        );
        assertEq(startTimestamp, startTimestamp_);
        assertEq(durationSeconds, DURATION_SECONDS);
        assertEq(lpToken, address(0));
    }

    function test_PerformShouldReturnFTOState() public {
        _perform();
        assertTrue(address(yexFTOPair.lpToken()) != address(0));
        assertEq(
            uint256(yexFTOPair.FTOState()),
            uint256(IYexFTOPairV2.Status.Success)
        );
    }

    function test_PerformShouldReturnLpBalance() public {
        _perform();

        (
            ,
            uint256 totalLp,
            uint256 zeroLp,
            uint256 ftoPairLp,
            uint256 feeLp,
            uint256 customHookLp
        ) = _getLPFactors();

        assertEq(ftoPairLp + feeLp + customHookLp + zeroLp, totalLp);

        uint256 liquidity = totalLp - zeroLp;
        uint256 calculatedPairLp = (liquidity *
            (100 - yexFTOPair.feePercent())) / 100;

        assertEq(liquidity - calculatedPairLp, feeLp);

        assertEq(
            (calculatedPairLp * yexFTOPair.percent4hook()) / 100,
            customHookLp
        );
        assertEq(
            calculatedPairLp -
                (calculatedPairLp * yexFTOPair.percent4hook()) /
                100,
            ftoPairLp
        );
    }

    function test_VestingShouldExecuteRelease() public {
        _perform();

        assertEq(hook.releasable(address(yexFTOPair)), 0);
        assertEq(
            hook.vestedAmount(address(yexFTOPair), uint64(block.timestamp)),
            0
        );

        HenloDexPair dexPair = HenloDexPair(yexFTOPair.lpToken());

        // 100s have passed since the vesting started
        uint64 newTimestamp = uint64(startTimestamp + 100);
        vm.warp(newTimestamp);

        uint256 totalVestingAmount = dexPair.balanceOf(address(hook));
        uint256 vestedAmount = (dexPair.balanceOf(address(hook)) *
            (newTimestamp - startTimestamp)) / DURATION_SECONDS;

        assertEq(hook.releasable(address(yexFTOPair)), vestedAmount);
        assertEq(
            hook.vestedAmount(address(yexFTOPair), newTimestamp),
            vestedAmount
        );

        hook.release(address(yexFTOPair));

        uint256 releasedAmount = vestedAmount;

        totalVestingAmount = totalVestingAmount - releasedAmount;
        assertEq(totalVestingAmount, dexPair.balanceOf(address(hook)));

        // 200s have passed since the vesting started
        newTimestamp = uint64(startTimestamp + 200);
        vm.warp(newTimestamp);

        vestedAmount =
            ((dexPair.balanceOf(address(hook)) + vestedAmount) *
                (newTimestamp - startTimestamp)) /
            DURATION_SECONDS;

        assertEq(
            hook.vestedAmount(address(yexFTOPair), newTimestamp),
            vestedAmount
        );
        assertEq(
            hook.releasable(address(yexFTOPair)),
            vestedAmount - releasedAmount
        );

        hook.release(address(yexFTOPair));

        releasedAmount = vestedAmount - releasedAmount;

        totalVestingAmount = totalVestingAmount - releasedAmount;

        assertEq(totalVestingAmount, dexPair.balanceOf(address(hook)));

        // vesting period is finished
        newTimestamp = uint64(
            startTimestamp + hook.duration(address(yexFTOPair)) + 10
        );
        vm.warp(newTimestamp);

        hook.release(address(yexFTOPair));

        assertEq(dexPair.balanceOf(address(hook)), 0);
    }

    function test_WithdrawRaisedTokenShouldExecute() public {
        _perform();

        (
            HenloDexPair dexPair,
            uint256 totalLp,
            uint256 zeroLp,
            uint256 ftoPairLp,
            uint256 feeLp,

        ) = _getLPFactors();

        vm.expectRevert(
            abi.encodeWithSelector(
                YexFTOPairV2.Unauthorized.selector,
                address(this)
            )
        );
        yexFTOPair.withdrawRaisedToken();

        uint256 liquidity = totalLp - zeroLp - feeLp;

        uint256 calculatedFtoPairLp = liquidity -
            (liquidity * yexFTOPair.percent4hook()) /
            100;

        assertEq(calculatedFtoPairLp, ftoPairLp);

        // simulate burn logic
        address _token0 = yexFTOPair.raisedToken() < yexFTOPair.launchedToken()
            ? yexFTOPair.raisedToken()
            : yexFTOPair.launchedToken();
        address _token1 = yexFTOPair.raisedToken() >= yexFTOPair.launchedToken()
            ? yexFTOPair.raisedToken()
            : yexFTOPair.launchedToken();

        uint256 balance0 = IERC20(_token0).balanceOf(address(dexPair));
        uint256 balance1 = IERC20(_token1).balanceOf(address(dexPair));

        liquidity = calculatedFtoPairLp / 2;
        totalLp = dexPair.totalSupply();
        uint256 amount0 = (liquidity * balance0) / totalLp;
        uint256 amount1 = (liquidity * balance1) / totalLp;

        hook.withdrawRaisedToken(address(yexFTOPair));

        assertEq(
            calculatedFtoPairLp - calculatedFtoPairLp / 2,
            dexPair.balanceOf(address(yexFTOPair))
        );
        assertEq(
            IERC20(yexFTOPair.raisedToken()).balanceOf(RECEIVER),
            (yexFTOPair.raisedToken() == _token0 ? amount0 : amount1)
        );
    }
}
