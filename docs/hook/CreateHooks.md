# Solidity API

## CreateHooks

Just a demo for create Hook
@title
@author
@notice

### EXECUTE_FLAG

```solidity
uint256 EXECUTE_FLAG
```

### LIQUIDITY_HOOK_OP_FLAG

```solidity
uint256 LIQUIDITY_HOOK_OP_FLAG
```

### BURNABLE_FLAG

```solidity
uint256 BURNABLE_FLAG
```

### pairAddr

```solidity
address pairAddr
```

### constructor

```solidity
constructor() public
```

### findSalt

```solidity
function findSalt(address _ftoFactory) external view returns (address pair, bytes32 salt)
```

### createHook

```solidity
function createHook(bytes32 salt, address _ftoFactory) external returns (address pair)
```

