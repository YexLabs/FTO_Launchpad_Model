# Solidity API

## CustomHook

This is a hook contract that provides vesting and remove/burn functions.

### CustomHookParam

```solidity
struct CustomHookParam {
  uint64 startTimestamp;
  uint64 durationSeconds;
  address receiver;
}
```

### constructor

```solidity
constructor(address _ftoFactory) public
```

### createFTO

```solidity
function createFTO(address raisedToken, string name, string symbol, uint256 amount, uint256 launchedTokenPercent, address poolHandler, uint256 raisingCycle, bytes data) public virtual
```

### execute

```solidity
function execute(bytes data) public
```

_A function called by the FTOPair contract
- Save the vesting information in getPair. (for vesting functionality)
- Register the withdrawal address for the RaisedToken. (for remove/burn functionality)
- The [onlyWhenLocked] modifier ensures that this function is called only when lock is set to 1.
  call [createFTO] function -> call [createFTO] function of the FtoFactory
  -> call [initialize] function of FTOPair -> call [execute] function
  msg.sender has to be FTOPair.
- Decode data to obtain [startTimestamp], [durationSeconds] and [receiver]._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| data | bytes | bytes data sent from the FTOPair |

### liquidityHookOp

```solidity
function liquidityHookOp(address lpToken, uint256 lpAmount) public
```

_A function that performs the vesting of LP tokens for FTOPair.
This function can only be called by the FTOPair contract.
After successfully adding liquidity to the AMM pool upon completing the fundraising,
 the FTOPair calls this function.
It transfers the LP tokens from FTOPair to this contract._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| lpToken | address | The liquidity token address of FTOPair |
| lpAmount | uint256 | The amount of LP tokens to be vested |

### withdrawRaisedToken

```solidity
function withdrawRaisedToken(address ftoPair) public
```

_This function provides the feature to remove LP & burn LaunchedTokens.
It is a permissionless function that can be called by anyone._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ftoPair | address | FTOPair contract address |

### getFlags

```solidity
function getFlags() public pure returns (struct YexFTOHook.Flags)
```

