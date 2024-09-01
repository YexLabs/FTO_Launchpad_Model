# Solidity API

## HenloDexFactory

### feeTo

```solidity
address feeTo
```

### feeToSetter

```solidity
address feeToSetter
```

### INIT_CODE_PAIR_HASH

```solidity
bytes32 INIT_CODE_PAIR_HASH
```

### getPair

```solidity
mapping(address => mapping(address => address)) getPair
```

### allPairs

```solidity
address[] allPairs
```

### constructor

```solidity
constructor(address _feeToSetter) public
```

### allPairsLength

```solidity
function allPairsLength() external view returns (uint256)
```

### pairCodeHash

```solidity
function pairCodeHash() external pure returns (bytes32)
```

### createPair

```solidity
function createPair(address tokenA, address tokenB) external returns (address pair)
```

### setFeeTo

```solidity
function setFeeTo(address _feeTo) external
```

### setFeeToSetter

```solidity
function setFeeToSetter(address _feeToSetter) external
```

