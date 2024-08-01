# Solidity API

## YexFTOPair

### fee

```solidity
uint256 fee
```

### raisedToken

```solidity
address raisedToken
```

### launchedToken

```solidity
address launchedToken
```

### launchedTokenProvider

```solidity
address launchedTokenProvider
```

### depositedRaisedToken

```solidity
uint256 depositedRaisedToken
```

### depositedLaunchedToken

```solidity
uint256 depositedLaunchedToken
```

### factory

```solidity
address factory
```

### startTime

```solidity
uint256 startTime
```

### endTime

```solidity
uint256 endTime
```

### otherPool

```solidity
address otherPool
```

### poolLP

```solidity
uint256 poolLP
```

### raisedTokenReserve

```solidity
uint256 raisedTokenReserve
```

### FTOState

```solidity
enum IYexFTOPair.Status FTOState
```

### raisedTokenDeposit

```solidity
mapping(address => uint256) raisedTokenDeposit
```

### claimedLp

```solidity
mapping(address => uint256) claimedLp
```

### raisedTokenDepositAddress

```solidity
address[] raisedTokenDepositAddress
```

### InvalidAmount

```solidity
error InvalidAmount()
```

### InvalidUpdate

```solidity
error InvalidUpdate()
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
function initialize(address _raisedToken, address _launchedToken, address _launchedTokenProvider, address _otherPool, uint256 raisingCycle) external
```

### depositLaunchedToken

```solidity
function depositLaunchedToken(address depositer, uint256 amount) external
```

### depositRaisedToken

```solidity
function depositRaisedToken(address depositer, uint256 amount) external
```

### refundRaisedToken

```solidity
function refundRaisedToken(address depositer) external
```

### withdraw

```solidity
function withdraw(address withdrawer) external
```

### claimLP

```solidity
function claimLP(address claimer) external
```

### claimableLP

```solidity
function claimableLP(address claimer) external view returns (uint256)
```

### _calculateLPAmount

```solidity
function _calculateLPAmount(address caller) internal view returns (uint256 lpAmount)
```

### _perform

```solidity
function _perform() internal
```

### checkUpkeep

```solidity
function checkUpkeep(bytes) external view returns (bool upkeepNeeded, bytes performData)
```

### performUpkeep

```solidity
function performUpkeep(bytes) external
```

### pause

```solidity
function pause() external
```

### resume

```solidity
function resume() external
```

### withdrawFee

```solidity
function withdrawFee(address feeTo) external
```

