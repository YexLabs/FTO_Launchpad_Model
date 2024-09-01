// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "../interfaces/IYexFTOHook.sol";
import "../interfaces/IYexFTOFactoryV2.sol";
import "./../libraries/TransferHelper.sol";
import "./../libraries/YexFTOHook.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @notice The base hook contract that all custom hooks used in the FTO Launchpad must inherit.
/// @dev Custom hook contract developers are also encouraged to inherit from this contract when developing hooks.
abstract contract NormalHook is ERC165, IYexFTOHook {
    error NotImplemented();
    error FactoryError();

    /// @notice The address of the YexFTOFactory
    address public immutable ftoFactory;

    constructor(address _ftoFactory) {
        if (_ftoFactory == address(0)) {
            revert FactoryError();
        }
        ftoFactory = _ftoFactory;

        /**
         * It validates whether the address of the hook contract meets the conditions set by the hook's Flags.
         * It uses the [validateHookAddress] function from the YexFTOHook library.
         * If the validation fails, the deployment of the hook contract also fails.
         * Hooks inheriting from NormalHook must pass this validation during deployment
         *  to ensure the validity of their own address.
         */
        YexFTOHook.validateHookAddress(address(this), getFlags());
    }

    /**
     * @dev Returns the YexFTOHook.Flags uniquely set for each hook.
     * Each hook can override this function by inheriting it.
     */
    function getFlags() public pure virtual returns (YexFTOHook.Flags memory);

    /**
     * @dev Overrides the standard function of ERC165
     * External entities use this function
     *  to check whether hooks inheriting from NormalHook support the hook interface.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IYexFTOHook).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev A function that calls the createFTO function of YexFTOFactory
     * When calling this function, the Token Launcher adds the hook parameter to [data],
     *  implying that it intends to create an FTO Launchpad using the hook in YexFTOFactory.
     * The FTO Launchpad recognizes this contract as the hook address.
     * @param raisedToken Token address for investment in FTO fundraising
     * @param name The name of the LaunchedToken
     * @param symbol The symbol of the LaunchedToken
     * @param amount The totalSupply of LaunchedToken, which is initially minted in its entirety
     * @param launchedTokenPercent The proportion of LaunchedToken added to the AMM Pool
     * @param poolHandler The router address of DEX
     * @param raisingCycle Fundraising period (in seconds)
     * @param data The bytes data to be passed to this hook contract after creating the FTO Launchpad
     *               - This value must never be empty.
     *               - If this value is empty,
     *                  the Launchpad will recognize that the Token Launcher is not using a custom hook.
     *               - The data must follow the decode format specific to this hook contract.
     */
    function createFTO(
        address raisedToken,
        string calldata name,
        string calldata symbol,
        uint256 amount,
        uint256 launchedTokenPercent,
        address poolHandler,
        uint256 raisingCycle,
        bytes calldata data
    ) public virtual {
        IYexFTOFactoryV2(ftoFactory).createFTO(
            raisedToken,
            name,
            symbol,
            amount,
            launchedTokenPercent,
            poolHandler,
            raisingCycle,
            data
        );
    }

    function withdrawRaisedToken(address /*ftoPair*/) external virtual {
        revert NotImplemented();
    }

    function execute(bytes calldata /*params*/) external virtual {
        revert NotImplemented();
    }

    function liquidityHookOp(
        address /*lpToken*/,
        uint256 /*lpAmount*/
    ) public virtual override {
        revert NotImplemented();
    }
}
