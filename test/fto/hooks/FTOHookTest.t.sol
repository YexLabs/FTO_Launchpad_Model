// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
// import {IYexFTOFactoryV2} from "../../../contracts/interfaces/IYexFTOFactoryV2.sol";
import {ERC20Faucet} from "../../../contracts/core/ERC20Faucet.sol";
import {YexFTOFactoryV2} from "../../../contracts/core/YexFTOFactoryV2.sol";
import {YexFTOFacadeV2} from "../../../contracts/core/YexFTOFacadeV2.sol";
import {HenloDexFactory} from "../../../contracts/core/HenloDexFactory.sol";
import {HenloDexRouterV2} from "../../../contracts/periphery/HenloDexRouterV2.sol";

import {YexFTOHook} from "../../../contracts/libraries/YexFTOHook.sol";
import {HookMiner} from "../../../contracts/libraries/HookMiner.sol";
import {CustomHook} from "../../../contracts/hook/CustomHook.sol";

contract FTOHookTest is Test {
    struct FTOParams {
        string NAME;
        string SYMBOL;
        uint256 AMOUNT;
        uint8 LAUNCHED_TOKEN_PERCENT;
        uint256 RAISING_CYCLE;
        bytes DATA;
    }

    ERC20Faucet private usdt;
    YexFTOFactoryV2 private yexFTOFactory;
    YexFTOFacadeV2 private yexFTOFacade;
    HenloDexFactory private henloDexFactory;
    HenloDexRouterV2 private henloDexRouter;
    CustomHook private hook;

    address private hookAddress;

    function setUp() public {
        usdt = new ERC20Faucet("usdt", "usdt");
        yexFTOFactory = new YexFTOFactoryV2();
        yexFTOFactory.addRaisedToken(address(usdt));
        yexFTOFacade = new YexFTOFacadeV2(address(yexFTOFactory));

        henloDexFactory = new HenloDexFactory(address(this));
        henloDexRouter = new HenloDexRouterV2(
            address(henloDexFactory),
            address(usdt)
        );

        yexFTOFactory.addWhiteList(address(this));

        // create hook
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
    }

    function test_DeployContracts() public view {
        assertTrue(address(usdt) != address(0));
        assertTrue(address(yexFTOFactory) != address(0));
        assertTrue(address(yexFTOFacade) != address(0));
        assertTrue(address(henloDexFactory) != address(0));
        assertTrue(address(henloDexRouter) != address(0));
        assertTrue(address(hook) == hookAddress);
    }

    function createFTO(
        YexFTOFactoryV2 factory,
        address tokenLauncher,
        address raisedToken,
        address dexRouter,
        FTOParams memory params
    ) internal {
        factory.createFTO(
            raisedToken,
            params.NAME,
            params.SYMBOL,
            params.AMOUNT,
            params.LAUNCHED_TOKEN_PERCENT,
            dexRouter,
            params.RAISING_CYCLE,
            params.DATA
        );
    }

    function test_CreateFTO() public {
        FTOParams memory params = FTOParams({
            NAME: "Test Token",
            SYMBOL: "TST",
            AMOUNT: 1000000000 ether,
            LAUNCHED_TOKEN_PERCENT: 50,
            RAISING_CYCLE: 100,
            DATA: "0x"
        });

        createFTO(
            yexFTOFactory,
            address(this),
            address(usdt),
            address(henloDexRouter),
            params
        );
    }
}
