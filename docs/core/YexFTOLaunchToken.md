# Solidity API

## YexFTOLaunchToken

The LaunchedToken to be used in the FTO Launchpad

### MINTER_ROLE

```solidity
bytes32 MINTER_ROLE
```

### BURNER_ROLE

```solidity
bytes32 BURNER_ROLE
```

### constructor

```solidity
constructor(string name_, string symbol_, address provider_) public
```

### mint

```solidity
function mint(address to, uint256 amount) public
```

_This function is called only once by the FTOFactory._

### burn

```solidity
function burn(uint256 amount) public
```

_This function can only be called by the token launcher or hook.
The token launcher or hook can only burn their own balance._

