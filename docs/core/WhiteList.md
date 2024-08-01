# Solidity API

## WhiteList

### whiteListMapping

```solidity
mapping(address => bool) whiteListMapping
```

### onlyWhiteList

```solidity
modifier onlyWhiteList()
```

### _checkWhiteList

```solidity
function _checkWhiteList(address user) internal view virtual
```

### addWhiteList

```solidity
function addWhiteList(address user) external
```

### batchAddWhiteList

```solidity
function batchAddWhiteList(address[] user) external
```

### removeWhiteList

```solidity
function removeWhiteList(address user) external
```

