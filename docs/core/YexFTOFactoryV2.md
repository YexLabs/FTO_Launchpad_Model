# Solidity API

## YexFTOFactoryV2

Creating Launch Token and FTO launchpad.

### allPairs

```solidity
address[] allPairs
```

### raisedTokens

```solidity
address[] raisedTokens
```

_List of RaisedToken addresses allowed for fundraising in the FTO Launchpad_

### INIT_CODE_PAIR_HASH

```solidity
bytes32 INIT_CODE_PAIR_HASH
```

### getPair

```solidity
mapping(address => mapping(address => address)) getPair
```

_[LaunchedToken][RaisedToken] => FTOPair address_

### isRaisedToken

```solidity
mapping(address => bool) isRaisedToken
```

### NotParticipateInThisFTOPair

```solidity
error NotParticipateInThisFTOPair()
```

### NotAllowedRaisedToken

```solidity
error NotAllowedRaisedToken()
```

### IdenticalAddress

```solidity
error IdenticalAddress(address launchedToken)
```

### YexFTOPairExists

```solidity
error YexFTOPairExists(address token0, address token1)
```

### TokenAddressIsZero

```solidity
error TokenAddressIsZero()
```

### FeeToAddressIsZero

```solidity
error FeeToAddressIsZero()
```

### LpTokenAddressIsZero

```solidity
error LpTokenAddressIsZero()
```

### addEvent

```solidity
function addEvent(address depositor, address ftoPair) external
```

_If a depositor participates in the FTO fundraising, add the FTOPair address to the eventParticipants[depositor] array.
This function is called by YexFTOPair contract after the depositor deposits RaisedToken in the FTOPair._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| depositor | address | Address of participant in the FTO fundraising |
| ftoPair | address | Address of FTOPair |

### events

```solidity
function events(address depositor) external view returns (address[] pairs)
```

Returns the list of FTOPairs that the depositor has participated in.

### addRaisedToken

```solidity
function addRaisedToken(address _raisedToken) external
```

Add raisedToken

_This function add a new token used for investment.
Only the factory owner can call this function._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _raisedToken | address | Token address for investment in FTO fundraising |

### removeRaisedToken

```solidity
function removeRaisedToken(address _raisedToken) external
```

Remove raisedToken

_This function remove a token used for investment.
Only the factory owner can call this function._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _raisedToken | address | Token address for investment in FTO fundraising |

### createFTO

```solidity
function createFTO(address raisedToken, string name, string symbol, uint256 _amount, uint256 launchedTokenPercent, address poolHandler, uint256 raisingCycle, bytes data) external returns (address pair)
```

Creates Launch Token and FTOPair

_This function can be called from the Token Launcher's address or Hook contract.
Deploy the LaunchedToken, create the FTOPair, mint LaunchedToken on FTOPair and initialize the FTOPair._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| raisedToken | address | Token address for investment in FTO fundraising |
| name | string | The name of the LaunchedToken |
| symbol | string | The symbol of the LaunchedToken |
| _amount | uint256 | The totalSupply of LaunchedToken, which is initially minted in its entirety |
| launchedTokenPercent | uint256 | The proportion of LaunchedToken added to the AMM Pool |
| poolHandler | address | The router address of DEX |
| raisingCycle | uint256 | Fundraising period (in seconds) |
| data | bytes | Data to be passed to the Hook; empty if LaunchPad does not use a hook |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| pair | address | The address of the newly created FTO Pair |

### allPairsLength

```solidity
function allPairsLength() external view returns (uint256)
```

### allRaisedTokens

```solidity
function allRaisedTokens() external view returns (address[])
```

### _createPair

```solidity
function _createPair(address raisedToken, address launchedToken, address launchedTokenProvider, uint256 launchedTokenPercent, uint256 launchedTokenSupply, address swapHandler, uint256 raisingCycle, bytes data) internal returns (address pair)
```

_Deploy the FTOPair using create2
and mint LaunchedToken on FTOPair
and call the [initialize] function of FTOPair to initialize it.
This function is called after the LaunchedToken is deployed._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| raisedToken | address | Token address for investment in FTO fundraising |
| launchedToken | address | The address of LaunchedToken |
| launchedTokenProvider | address | When not using a custom hook, the address of the Token Launcher; when using a custom hook, the address of the hook contract |
| launchedTokenPercent | uint256 | The proportion of LaunchedToken added to the DEX Pool |
| launchedTokenSupply | uint256 | The totalSupply of LaunchedToken, which is initially minted in its entirety |
| swapHandler | address | The router address of DEX |
| raisingCycle | uint256 | Fundraising period (in seconds) |
| data | bytes | Data to be passed to the Hook; empty if LaunchPad does not use a hook |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| pair | address | The address of the newly created FTO Pair |

### _afterCreatePair

```solidity
function _afterCreatePair(address pair) internal
```

### pause

```solidity
function pause(address raisedToken, address launchedToken) external
```

_This function pauses the fundraising of the FTOPair.
Only the factory owner can call this function.
It can only be paused if the FTOPair status is Processing.
After calling this function, depositors can withdraw their RaisedToken invested in the FTOPair.
After calling this function, the token provider can withdraw all the LaunchedToken from the FTOPair._

### resume

```solidity
function resume(address raisedToken, address launchedToken) external
```

_This function resumes the fundraising status of the FTOPair that was paused.
Only the factory owner can call this function.
It can only be resumed if the FTOPair status is Paused._

### getFTOPairProvider

```solidity
function getFTOPairProvider(address raisedToken, address launchedToken) public view returns (address provider)
```

### withdrawFee

```solidity
function withdrawFee(address raisedToken, address launchedToken, address feeTo) external
```

Withdraws the accumulated LPToken received as a fee from the FTOPair.

_This function withdraws the LPToken received as a fee from the FTOPair after a successful fundraising in the FTOPair Launchpad.
Only the factory owner can call this function, and the ftoPair must be specified with [raisedToken, launchedToken]._

