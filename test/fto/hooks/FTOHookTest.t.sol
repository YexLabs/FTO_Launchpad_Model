// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import {ERC20Faucet} from "../../../contracts/core/ERC20Faucet.sol";
import {YexFTOFactoryV2} from "../../../contracts/core/YexFTOFactoryV2.sol";
import {YexFTOFacadeV2} from "../../../contracts/core/YexFTOFacadeV2.sol";
import {YexFTOPairV2} from "../../../contracts/core/YexFTOPairV2.sol";
import {HenloDexFactory} from "../../../contracts/core/HenloDexFactory.sol";
import {HenloDexRouterV2} from "../../../contracts/periphery/HenloDexRouterV2.sol";
import {YexFTOHook} from "../../../contracts/libraries/YexFTOHook.sol";
import {IYexFTOHook} from "../../../contracts/interfaces/IYexFTOHook.sol";

abstract contract FTOHookTest is Test {
    struct FTOParams {
        string NAME;
        string SYMBOL;
        uint256 AMOUNT;
        uint8 LAUNCHED_TOKEN_PERCENT;
        uint256 RAISING_CYCLE;
        bytes DATA;
    }

    ERC20Faucet public usdt;
    YexFTOFactoryV2 public yexFTOFactory;
    YexFTOFacadeV2 public yexFTOFacade;
    YexFTOPairV2 public yexFTOPair;
    HenloDexFactory public henloDexFactory;
    HenloDexRouterV2 public henloDexRouter;

    uint256[] public depositAmounts;

    function _deployContracts() internal virtual {
        usdt = new ERC20Faucet("usdt", "usdt");
        yexFTOFactory = new YexFTOFactoryV2();
        yexFTOFactory.addRaisedToken(address(usdt));
        yexFTOFacade = new YexFTOFacadeV2(address(yexFTOFactory));

        henloDexFactory = new HenloDexFactory(address(this));
        henloDexRouter = new HenloDexRouterV2(
            address(henloDexFactory),
            address(usdt)
        );
    }

    function _createFTO(
        address hook,
        address raisedToken,
        address dexRouter,
        FTOParams memory params
    ) internal virtual {
        IYexFTOHook(hook).createFTO(
            raisedToken,
            params.NAME,
            params.SYMBOL,
            params.AMOUNT,
            params.LAUNCHED_TOKEN_PERCENT,
            dexRouter,
            params.RAISING_CYCLE,
            params.DATA
        );

        uint256 ftoPairsLength = yexFTOFactory.allPairsLength();
        address createdPair = yexFTOFactory.allPairs(ftoPairsLength - 1);
        yexFTOPair = YexFTOPairV2(createdPair);
    }

    function _depositRaisedTokens() internal virtual {
        require(depositAmounts.length > 0, "Amounts array is empty");
        for (uint256 i = 0; i < depositAmounts.length; i++) {
            address depositor = vm.addr(i + 1);
            vm.startPrank(depositor);
            usdt.faucet();
            usdt.approve(address(yexFTOFacade), depositAmounts[i]);

            yexFTOFacade.deposit(
                address(usdt),
                yexFTOPair.launchedToken(),
                depositAmounts[i]
            );
            vm.stopPrank();
        }
    }
}
