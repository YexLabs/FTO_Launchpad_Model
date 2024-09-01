# Solidity API

## VestingHook

This is a hook contract that provides vesting functionality.

### ERC20Released

```solidity
event ERC20Released(address token, uint256 amount)
```

### VestingHookParam

```solidity
struct VestingHookParam {
  uint64 startTimestamp;
  uint64 durationSeconds;
}
```

### VestingInfo

```solidity
struct VestingInfo {
  address beneficiaryAddress;
  uint64 startTimestamp;
  uint64 durationSeconds;
  address lpToken;
}
```

### getPair

```solidity
mapping(address => struct VestingHook.VestingInfo) getPair
```

### CallerIsNotFTOPair

```solidity
error CallerIsNotFTOPair(address caller)
```

### InvalidVestingStartTime

```solidity
error InvalidVestingStartTime()
```

### onlyFTOPair

```solidity
modifier onlyFTOPair()
```

_The function is restricted to execute only if the msg.sender is the FTOPair contract._

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
- Save the vesting information in getPair.
- The [onlyWhenLocked] modifier ensures that this function is called only when lock is set to 1.
  call [createFTO] function -> call [createFTO] function of the FtoFactory
  -> call [initialize] function of FTOPair -> call [execute] function
  msg.sender has to be FTOPair.
- Decode data to obtain vesting-related info; [startTimestamp] and [durationSeconds].
- Set the address of the msg.sender;FTOPair, as the beneficiaryAddress._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| data | bytes | bytes data sent from the FTOPair |

### _setVestingHookParam

```solidity
function _setVestingHookParam(struct VestingHook.VestingHookParam params) internal
```

### liquidityHookOp

```solidity
function liquidityHookOp(address lpToken, uint256 lpAmount) public virtual
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

### beneficiary

```solidity
function beneficiary(address ftoPair) public view virtual returns (address)
```

_Getter for the beneficiary address._

### start

```solidity
function start(address ftoPair) public view virtual returns (uint256)
```

_Getter for the start timestamp._

### duration

```solidity
function duration(address ftoPair) public view virtual returns (uint256)
```

_Getter for the vesting duration._

### released

```solidity
function released(address ftoPair) public view virtual returns (uint256)
```

_Amount of token already released_

### releasable

```solidity
function releasable(address ftoPair) public view virtual returns (uint256)
```

_Getter for the amount of releasable `token` tokens. `token` should be the address of an
IERC20 contract._

### release

```solidity
function release(address ftoPair) public virtual
```

_Release the tokens that have already vested.

Emits a {ERC20Released} event._

### vestedAmount

```solidity
function vestedAmount(address ftoPair, uint64 timestamp) public view virtual returns (uint256)
```

_Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve._

### _vestingSchedule

```solidity
function _vestingSchedule(address ftoPair, uint256 totalAllocation, uint64 timestamp) internal view virtual returns (uint256)
```

_Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
an asset given its total historical allocation._

### getFlags

```solidity
function getFlags() public pure virtual returns (struct YexFTOHook.Flags)
```

_Returns the YexFTOHook.Flags uniquely set for each hook.
Each hook can override this function by inheriting it._

