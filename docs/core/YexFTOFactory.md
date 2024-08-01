# Solidity API

## RegistrationParams

```solidity
struct RegistrationParams {
  string name;
  bytes encryptedEmail;
  address upkeepContract;
  uint32 gasLimit;
  address adminAddress;
  uint8 triggerType;
  bytes checkData;
  bytes triggerConfig;
  bytes offchainConfig;
  uint96 amount;
}
```

## AutomationRegistrarInterface

string name = "test upkeep";
bytes encryptedEmail = 0x;
address upkeepContract = 0x...;
uint32 gasLimit = 500000;
address adminAddress = 0x....;
uint8 triggerType = 0;
bytes checkData = 0x;
bytes triggerConfig = 0x;
bytes offchainConfig = 0x;
uint96 amount = 1000000000000000000;

### registerUpkeep

```solidity
function registerUpkeep(struct RegistrationParams requestParams) external returns (uint256)
```

## ERC20Mintable

### constructor

```solidity
constructor(string name_, string symbol_) public
```

### mint

```solidity
function mint(address to, uint256 amount) public
```

## YexFTOFactory

### allPairs

```solidity
address[] allPairs
```

### raisedTokens

```solidity
address[] raisedTokens
```

### INIT_CODE_PAIR_HASH

```solidity
bytes32 INIT_CODE_PAIR_HASH
```

### getPair

```solidity
mapping(address => mapping(address => address)) getPair
```

### isRaisedToken

```solidity
mapping(address => bool) isRaisedToken
```

### i_link

```solidity
contract LinkTokenInterface i_link
```

### i_registrar

```solidity
contract AutomationRegistrarInterface i_registrar
```

### addEvent

```solidity
function addEvent(address depositer, address ftoPair) external
```

### events

```solidity
function events(address depositer) external view returns (address[] pairs)
```

### addRaisedToken

```solidity
function addRaisedToken(address _raisedToken) external
```

### removeRaisedToken

```solidity
function removeRaisedToken(address _raisedToken) external
```

### createFTO

```solidity
function createFTO(address provider, address raisedToken, string name, string symbol, uint256 _amount, address poolHandler, uint256 raisingCycle) external returns (address pair)
```

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
function _createPair(address raisedToken, address launchedToken, address launchedTokenProvider, address swapHandler, uint256 raisingCycle) internal returns (address pair)
```

### _afterCreatePair

```solidity
function _afterCreatePair(address pair) internal
```

### pause

```solidity
function pause(address raisedToken, address launchedToken) external
```

### resume

```solidity
function resume(address raisedToken, address launchedToken) external
```

### getFTOPairProvider

```solidity
function getFTOPairProvider(address raisedToken, address launchedToken) public view returns (address provider)
```

### withdrawFee

```solidity
function withdrawFee(address raisedToken, address launchedToken, address feeTo) external
```

