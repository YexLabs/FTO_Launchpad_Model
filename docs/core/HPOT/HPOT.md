# Solidity API

## HPOT

### MIN_MINT_INTERVAL

```solidity
uint256 MIN_MINT_INTERVAL
```

The minimum amount of time that must elapse before a mint is allowed

### MINT_CAP_NUMERATOR

```solidity
uint256 MINT_CAP_NUMERATOR
```

The maximum amount that can be can be minted - numerator

### MINT_CAP_DENOMINATOR

```solidity
uint256 MINT_CAP_DENOMINATOR
```

The maximum amount that can be can be minted - denominator

### nextMint

```solidity
uint256 nextMint
```

The time at which the next mint is allowed - timestamp

### constructor

```solidity
constructor() public
```

### initialize

```solidity
function initialize(uint256 _initialSupply, address _owner) public
```

Initial

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _initialSupply | uint256 | The amount of initial supply to mint |
| _owner | address | The owner of this contract - controls minting, not upgradeability |

### mint

```solidity
function mint(address recipient, uint256 amount) external
```

Allows the owner to mint new tokens

_Only allows minting below an inflation cap.
        Set to once per year, and a maximum of 2%._

### _afterTokenTransfer

```solidity
function _afterTokenTransfer(address from, address to, uint256 amount) internal
```

### _mint

```solidity
function _mint(address to, uint256 amount) internal
```

### _burn

```solidity
function _burn(address account, uint256 amount) internal
```

