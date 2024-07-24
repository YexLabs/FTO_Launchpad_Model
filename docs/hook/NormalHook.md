# Solidity API

## NormalHook

The base hook contract that all custom hooks used in the FTO Launchpad must inherit.

_Custom hook contract developers are also encouraged to inherit from this contract when developing hooks._

### NotImplemented

```solidity
error NotImplemented()
```

### ftoFactory

```solidity
address ftoFactory
```

The address of the YexFTOFactory

### constructor

```solidity
constructor(address _ftoFactory) internal
```

### getFlags

```solidity
function getFlags() public pure virtual returns (struct YexFTOHook.Flags)
```

_Returns the YexFTOHook.Flags uniquely set for each hook.
Each hook can override this function by inheriting it._

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool)
```

_Overrides the standard function of ERC165
External entities use this function
 to check whether hooks inheriting from NormalHook support the hook interface._

### createFTO

```solidity
function createFTO(address raisedToken, string name, string symbol, uint256 amount, uint256 launchedTokenPercent, address poolHandler, uint256 raisingCycle, bytes data) public virtual
```

_A function that calls the createFTO function of YexFTOFactory
When calling this function, the Token Launcher adds the hook parameter to [data],
 implying that it intends to create an FTO Launchpad using the hook in YexFTOFactory.
The FTO Launchpad recognizes this contract as the hook address._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| raisedToken | address | Token address for investment in FTO fundraising |
| name | string | The name of the LaunchedToken |
| symbol | string | The symbol of the LaunchedToken |
| amount | uint256 | The totalSupply of LaunchedToken, which is initially minted in its entirety |
| launchedTokenPercent | uint256 | The proportion of LaunchedToken added to the AMM Pool |
| poolHandler | address | The router address of DEX |
| raisingCycle | uint256 | Fundraising period (in seconds) |
| data | bytes | The bytes data to be passed to this hook contract after creating the FTO Launchpad               - This value must never be empty.               - If this value is empty,                  the Launchpad will recognize that the Token Launcher is not using a custom hook.               - The data must follow the decode format specific to this hook contract. |

### withdrawRaisedToken

```solidity
function withdrawRaisedToken(address) external virtual
```

### execute

```solidity
function execute(bytes) external virtual
```

### liquidityHookOp

```solidity
function liquidityHookOp(address, uint256) public virtual
```

