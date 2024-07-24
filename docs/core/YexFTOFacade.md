# Solidity API

## YexFTOFacade

The contract that directly interacts with the users.

### factory

```solidity
address factory
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
function deposit(address raisedToken, address launchedToken, uint256 raisedTokenAmount, uint256 launchedTokenAmount) external
```

Allows you to deposit RaisedToken or LaunchedToken into the FTO.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| raisedToken | address | the address of Raised Token |
| launchedToken | address | the address of Launched Token |
| raisedTokenAmount | uint256 | Amount of Raised Token to be deposited |
| launchedTokenAmount | uint256 | Amount of Launched Token to be deposited |

### withdraw

```solidity
function withdraw(address raisedToken, address launchedToken) external
```

_This function withdraws LaunchedToken from the FTO.
The function caller must be the token launcher or the hook._

### claimLP

```solidity
function claimLP(address raisedToken, address launchedToken) external
```

Claim the LP tokens from the FTO corresponding to your share.

### refundRaisedToken

```solidity
function refundRaisedToken(address raisedToken, address launchedToken) external
```

Withdraw your RaisedToken that was deposited in the FTO.

_This function will only succeed and not revert if the FTO status is Paused._

### claimableLP

```solidity
function claimableLP(address raisedToken, address launchedToken) external view returns (uint256)
```

Returns the amount of LP tokens you can claim from the FTO.

### _deposit

```solidity
function _deposit(address raisedToken, address launchedToken, uint256 raisedTokenAmount, uint256 launchedTokenAmount) internal
```

_Deposit RaisedToken and LaunchedToken by calling the depositRaisedToken()
 and depositLaunchedToken() functions of the FTOPair.
First, transfer the RaisedToken to the FTOPair, then call the depositRaisedToken() function.
First, transfer the LaunchedToken to the FTOPair, then call the depositLaunchedToken() function._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| raisedToken | address | the address of Raised Token |
| launchedToken | address | the address of Launched Token |
| raisedTokenAmount | uint256 | Amount of Raised Token to be deposited |
| launchedTokenAmount | uint256 | Amount of Launched Token to be deposited |

