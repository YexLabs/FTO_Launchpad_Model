## Notice, we need to change
1. Uniswap Library INIT_HASH_CODE
2. FTO Library INIT_HASH_CODE

## How to build?
0. for Test, you can run deployUSDT.sol to deploy your own erc20.
1. deploy FTO Factory, you can run 
   ``` shell
   npx hardhat run scripts/FTO/deployFactory.ts --network goerli   
   ```
   copy the INIT_HASH_CODE to YexFTOLibrary.sol
2. deploy FTO Facade, please replace the Factory addresss, and you can run 
   ``` shell
   npx hardhat run scripts/FTO/deployFacade.ts --network goerli   
   ```

## How to test?
1. USDT faucet
2. owner execute FTOFactory's "addWhiteList" to add a new caller "User A".
3. "User A" execute FTOFactory's "createFTO" to create a new FTO pair.
4. Other users can execute FTOFacade's "deposit" to deposit their token.
5. When the rasing time end, we sholud call FTOPair's "performUpkeep", then the reserves will be added to Uniswap's pool.
6. Users can claim their LP by execute FTOFacade's "claimLP"


## Notice
please remember when you interact with FTOFacade, you need to approve your token to FTOFacade as spender.