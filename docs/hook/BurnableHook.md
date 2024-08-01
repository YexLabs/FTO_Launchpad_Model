# Solidity API

## BurnableHook

This is a hook contract that provides the functionality to remove LP tokens and burn launched tokens.

### BurnableHookParam

```solidity
struct BurnableHookParam {
  address receiver;
}
```

### raisedTokenReceiver

```solidity
mapping(address => address) raisedTokenReceiver
```

_Addresses used as destinations by TokenProviders when withdrawing
 RaisedTokens from the hook contract after burning LaunchedTokens.
FTOPair address points to the withdrawal address._

### RaisedTokenReceiverIsZero

```solidity
error RaisedTokenReceiverIsZero()
```

_errors_

### InvalidClaimableLPAmount

```solidity
error InvalidClaimableLPAmount()
```

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

### execute

```solidity
function execute(bytes data) public virtual
```

_A function called by the FTOPair contract
- Register the withdrawal address for the RaisedToken.
- The [onlyWhenLocked] modifier ensures that this function is called only when lock is set to 1.
  call [createFTO] function -> call [createFTO] function of the FtoFactory
  -> call [initialize] function of FTOPair -> call [execute] function
  msg.sender has to be FTOPair.
- Decode data to obtain [receiver]._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| data | bytes | bytes data sent from the FTOPair |

### _setBurnableHookParam

```solidity
function _setBurnableHookParam(struct BurnableHook.BurnableHookParam params) internal
```

### withdrawRaisedToken

```solidity
function withdrawRaisedToken(address ftoPair) public virtual
```

_This function provides the feature to remove LP & burn LaunchedTokens.
It is a permissionless function that can be called by anyone._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ftoPair | address | FTOPair contract address |

### _withdrawRaisedToken

```solidity
function _withdrawRaisedToken(address ftoPair) internal
```

### getFlags

```solidity
function getFlags() public pure virtual returns (struct YexFTOHook.Flags)
```

_Returns the YexFTOHook.Flags uniquely set for each hook.
Each hook can override this function by inheriting it._

