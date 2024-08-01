# Solidity API

## YexFTOFacadeV2

The contract that directly interacts with the users.

### factory

```solidity
address factory
```

### InvalidRaisedTokenAmount

```solidity
error InvalidRaisedTokenAmount()
```

### constructor

```solidity
constructor(address _factory) public
```

### getFTOPair

```solidity
function getFTOPair(address raisedToken, address launchedToken) public view returns (address pair)
```

This function returns the FTOPair address derived from the raisedToken and launchedToken.

### getFTOPairProvider

```solidity
function getFTOPairProvider(address raisedToken, address launchedToken) public view returns (address provider)
```

This function returns the address of the token launcher or the hook for the FTO.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| raisedToken | address | the address of Raised Token |
| launchedToken | address | the address of Launched Token |

### getFTOState

```solidity
function getFTOState(address raisedToken, address launchedToken) public view returns (uint256 state)
```

Allows you to get the fundraising status of the FTO.

### deposit

```solidity
function deposit(address raisedToken, address launchedToken, uint256 raisedTokenAmount) external
```

Allows you to deposit RaisedToken into the FTO.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| raisedToken | address | the address of Raised Token |
| launchedToken | address | the address of Launched Token |
| raisedTokenAmount | uint256 | Amount of Raised Token to be deposited |

### claimLP

```solidity
function claimLP(address raisedToken, address launchedToken) external
```

Claim the LP tokens from the FTO corresponding to your share.

### claimLaunchedToken

```solidity
function claimLaunchedToken(address raisedToken, address launchedToken) external
```

Claim the LaunchedToken allocated to you as a reward.

### claimableLP

```solidity
function claimableLP(address raisedToken, address launchedToken) external view returns (uint256)
```

Returns the amount of LP tokens you can claim from the FTO.

### claimableLaunchedToken

```solidity
function claimableLaunchedToken(address raisedToken, address launchedToken) external view returns (uint256)
```

Returns the amount of LaunchedToken allocated to you as a reward that you can claim from the FTO.

### _deposit

```solidity
function _deposit(address raisedToken, address launchedToken, uint256 raisedTokenAmount) internal
```

_Deposit RaisedToken by calling the depositRaisedToken() function of the FTOPair
First, transfer the RaisedToken to the FTOPair, then call the depositRaisedToken() function._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| raisedToken | address | the address of Raised Token |
| launchedToken | address | the address of Launched Token |
| raisedTokenAmount | uint256 | Amount of Raised Token to be deposited |

