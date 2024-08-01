# Solidity API

## ITransferAndCall

### transferAndCall

```solidity
function transferAndCall(address to, uint256 value, bytes data) external returns (bool success)
```

### Transfer

```solidity
event Transfer(address from, address to, uint256 value, bytes data)
```

## ITransferAndCallReceiver

note that implementation of ITransferAndCallReceiver is not expected to return a success bool

### onTokenTransfer

```solidity
function onTokenTransfer(address _sender, uint256 _value, bytes _data) external
```

## TransferAndCallToken

based on Implementation from https://github.com/smartcontractkit/LinkToken/blob/8fd6d624d981e39e6e3f55a72732deb9f2f832d9/contracts/v0.6/ERC677.sol
The implementation doesn't return a bool on onTokenTransfer. This is similar to the proposed 677 standard, but still incompatible - thus we don't refer to it as such.

### transferAndCall

```solidity
function transferAndCall(address _to, uint256 _value, bytes _data) public virtual returns (bool success)
```

_transfer token to a contract address with additional data if the recipient is a contact._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _to | address | The address to transfer to. |
| _value | uint256 | The amount to be transferred. |
| _data | bytes | The extra data to be passed to the receiving contract. |

