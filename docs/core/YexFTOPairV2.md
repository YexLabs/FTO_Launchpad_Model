# Solidity API

## YexFTOPairV2

Created from the FTO Factory contract

_This contract address is uniquely determined by the RaisedToken and LaunchedToken._

### FTOPairErrorCode

```solidity
enum FTOPairErrorCode {
  NotInProcessing,
  Paused,
  NotPaused,
  NotSuccess,
  NotFinishedOrPaused
}
```

### feePercent

```solidity
uint8 feePercent
```

_The percentage of LP tokens received after adding liquidity to the AMM Pool that is paid to the Factory as a fee
The decimal for feePercent is 0._

### raisedToken

```solidity
address raisedToken
```

_Address of Raised Token
This value is set when the initialize function is called by the FTOFactory and does not change once set._

### launchedToken

```solidity
address launchedToken
```

_Address of Launched Token
This value is set when the initialize function is called by the FTOFactory and does not change once set._

### poolLaunchedTokenAmount

```solidity
uint256 poolLaunchedTokenAmount
```

_The amount of Launched Token to be provided as a reward to depositors
poolLaunchedTokenAmount = depositedLaunchedToken * (100 - launchPercent) / 100_

### launchedTokenProvider

```solidity
address launchedTokenProvider
```

_The entity that created the FTO Launchpad
The address of the Token Launcher if CustomHook is not used,
or the hook address if CustomHook is used._

### launchPercent

```solidity
uint256 launchPercent
```

_The amount of LaunchedToken added as liquidity to the AMM Pool, excluding the amount provided as a reward to depositors
rewardPercent = 100 - launchPercent
launchPercent defaults to 100%_

### depositedRaisedToken

```solidity
uint256 depositedRaisedToken
```

_The amount of RaisedToken deposited to address(this): FTOPair_

### depositedLaunchedToken

```solidity
uint256 depositedLaunchedToken
```

_The amount of LaunchedToken in the address(this): FTOPair_

### factory

```solidity
address factory
```

_The address of YexFTOFactory contract_

### startTime

```solidity
uint256 startTime
```

_The time when the fundraising for the FTO begins
Fundraising begins immediately upon the creation of the FTOPair contract._

### endTime

```solidity
uint256 endTime
```

_The time when the fundraising for the FTO ends
It is set in the initialize function._

### otherPool

```solidity
address otherPool
```

_The address of HenloDexRouter_

### lpToken

```solidity
address lpToken
```

_The address of the LP tokens received after adding liquidity to HenloDex_

### totalClaimedLp

```solidity
uint256 totalClaimedLp
```

_The total amount of LP tokens claimed by the TokenLauncher and depositors._

### FTOState

```solidity
enum IYexFTOPairV2.Status FTOState
```

_Indicates the status of the FTO. The status can be [Processing], [Paused], [Success], or [Failed]._

### raisedTokenDeposit

```solidity
mapping(address => uint256) raisedTokenDeposit
```

_The amount of RaisedToken deposited by each depositor
It is used to calculate the share of each depositor._

### claimedLp

```solidity
mapping(address => uint256) claimedLp
```

_The amount of LP tokens claimed by each user.
A user can be either a depositor or a token provider._

### claimedLaunchedToken

```solidity
mapping(address => bool) claimedLaunchedToken
```

_Indicates whether each depositor has claimed the LaunchedToken allocated as a reward_

### raisedTokenDepositAddress

```solidity
address[] raisedTokenDepositAddress
```

_List of depositors_

### percent4hook

```solidity
uint256 percent4hook
```

_The percentage of LP tokens that are vested in hook contract if the FTO uses a vesting hook.
It is set in the initialize function, and the decimal is 0._

### hook

```solidity
address hook
```

_The address of the hook contract if the FTO uses a custom hook
The hook is initially set in the initialize function._

### Locked

```solidity
error Locked()
```

_errors_

### InvalidAmount

```solidity
error InvalidAmount()
```

### NotDepositedRaisedToken

```solidity
error NotDepositedRaisedToken()
```

### FTOPairStatusError

```solidity
error FTOPairStatusError(enum YexFTOPairV2.FTOPairErrorCode code)
```

### Unauthorized

```solidity
error Unauthorized(address caller)
```

### RaisingTimeIsOver

```solidity
error RaisingTimeIsOver(uint256 currentTime, uint256 endTime)
```

### ProjectOwnerDepositNotAllowed

```solidity
error ProjectOwnerDepositNotAllowed(address depositor)
```

### NoClaimAmountRemaining

```solidity
error NoClaimAmountRemaining(uint256 lpAmount, uint256 claimedAmount)
```

### LaunchedTokenAlreadyClaimed

```solidity
error LaunchedTokenAlreadyClaimed(address claimer)
```

### NotDepositor

```solidity
error NotDepositor(address claimer)
```

### lock

```solidity
modifier lock()
```

### whenPaused

```solidity
modifier whenPaused()
```

### whenNotPaused

```solidity
modifier whenNotPaused()
```

### constructor

```solidity
constructor() public
```

### initialize

```solidity
function initialize(address _raisedToken, address _launchedToken, address _launchedTokenProvider, uint256 _launchedTokenPercent, address _otherPool, uint256 raisingCycle, bytes data) external
```

_This function performs the initial setup for the FTOPair.
This function can only be called by the FTOFactory and is called only once at the time of FTOPair deployment._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _raisedToken | address | Token address for investment in FTO fundraising |
| _launchedToken | address | The address of LaunchedToken |
| _launchedTokenProvider | address | When not using a custom hook, the address of the Token Launcher; when using a custom hook, the address of the hook contract |
| _launchedTokenPercent | uint256 | The proportion of LaunchedToken added to the DEX Pool |
| _otherPool | address | The router address of DEX |
| raisingCycle | uint256 | Fundraising period (in seconds) |
| data | bytes | Data to be passed to the hook contract; empty if FTO does not use a custom hook |

### depositRaisedToken

```solidity
function depositRaisedToken(address depositor, uint256 amount) external
```

_Function called after depositors deposit RaisedToken into the FTOPair
This function will not revert if the following conditions are met:
 1. The depositor first transfers the amount of RaisedToken to address(this).
 2. After [1] is completed, this function is called with the depositor and amount as parameters.
 3. The FTO status must be [Processing] and it must be during the fundraising period._

### refundRaisedToken

```solidity
function refundRaisedToken() external
```

_Transfer the entire amount of RaisedToken deposited back to the depositor's address.
Can only be called if the FTO status is [Paused].
The depositor must call this function directly._

### withdrawRaisedToken

```solidity
function withdrawRaisedToken() external
```

_Function that allows the [msg.sender] to claim LP tokens
This function can only be called by a hook contract that has a burnable function.
This function can only be called after the fundraising is completed,
  liquidity has been added to the Dex pool, and the FTO status is set to Success._

### claimLP

```solidity
function claimLP(address claimer) external
```

_Function that allows the [claimer] to claim LP tokens
This function can only be called after the fundraising is completed,
  liquidity has been added to the Dex pool, and the FTO status is set to Success._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| claimer | address | The address claiming the LP tokens; the address receiving the LP tokens |

### claimableLP

```solidity
function claimableLP(address claimer) external view returns (uint256)
```

_Calculates the amount of LP tokens the [claimer] can claim at the current time.
This value is calculated by subtracting the already claimed amount from lpAmount._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The amount of LP tokens the claimer can claim at the current time. |

### _calculateLPAmount

```solidity
function _calculateLPAmount(address caller) internal view returns (uint256 lpAmount)
```

_Calculates the total amount of LP tokens the [claimer] can claim from the FTOPair.
This value includes the amount already claimed._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| caller | address | address of claimer |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| lpAmount | uint256 | The total amount of LP tokens the claimer can claim. |

### claimLaunchedToken

```solidity
function claimLaunchedToken(address claimer) external
```

_This function claims the remaining LaunchedToken in the FTOPair after successful fundraising.
The remaining LaunchedToken in the FTOPair is provided as a reward to RaisedToken depositors in the FTO._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| claimer | address | Address of the RaisedToken depositor |

### claimableLaunchedToken

```solidity
function claimableLaunchedToken(address claimer) external view returns (uint256)
```

_This function returns the amount of LaunchedToken that the [claimer] can claim._

### _calculateLaunchedTokenAmount

```solidity
function _calculateLaunchedTokenAmount(address caller) internal view returns (uint256 amount)
```

_Calculates the amount of LaunchedToken the [claimer] can claim as a reward.
If already claimed, the amount is calculated as 0._

### _perform

```solidity
function _perform() internal
```

_This function supplies liquidity to the Dex pool using the accumulated LaunchedToken and RaisedToken
 in the FTO at the end of the fundraising period.
If there are no accumulated RaisedToken at the end of the fundraising period, the FTO status becomes Failed._

### _isUpkeepNeeded

```solidity
function _isUpkeepNeeded() internal view returns (bool)
```

_Check if the fundraising end time has passed and if the FTO status is not Paused.
This function checks whether the _perform function can be executed._

### checkUpkeep

```solidity
function checkUpkeep(bytes) external view returns (bool upkeepNeeded, bytes performData)
```

_Returns the result of the _isUpkeepNeeded() function.
Off-chain, this function is used to determine whether to call the [performUpkeep] function._

### performUpkeep

```solidity
function performUpkeep(bytes) external
```

_This is an external function that executes the _perform() function.
Within the function, it performs an additional check of _isUpkeepNeeded().
If _isUpkeepNeeded() returns true, it executes the _perform() function.
This function is a permissionless function that anyone can execute._

### getFtoPairTokenInfo

```solidity
function getFtoPairTokenInfo() external view returns (struct IYexFTOPairV2.FtoPairTokenInfo)
```

_Returns the addresses of the three tokens managed by the FTOPair._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | struct IYexFTOPairV2.FtoPairTokenInfo | A struct containing the addresses of the raised token, launched token, and LP token |

### pause

```solidity
function pause() external
```

_Changes the status of the FTO to Paused.
This function can only be called by the FTOFactory._

### resume

```solidity
function resume() external
```

_Resumes the status of the FTO that was Paused.
This function can only be called by the FTOFactory._

### withdrawFee

```solidity
function withdrawFee(address feeTo) external
```

