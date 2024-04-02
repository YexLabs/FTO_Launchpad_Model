## What is the FTO (Fair token Offering) Model

The FTO (Fair token Offering) Model is a new model that stands at the forefront of Defi innovation. This model launches LP tokens instead of a single token, providing the following advantages:

- **Fairness**: The project does not set the price or initial valuation in the beginning. Instead, it innovatively uses the AMM pool to dynamically determine the token price and project valuation. All users who participate in the launch gain the same price.
- **Liquidity management**: By launching LP tokens, our protocol enables the liquidity pool to be added to our Dex. This eliminates the need for the project to find a place to list the tokens.
- **Suitability for berachain**: Berachain has the best meme culture, and this mechanism takes the best use of it. The more people who participate in your token launches, the higher the token price.

## How the code is structured

- `YexFTOFacade.sol`: The contract that directly interacts with the users.
- `YexFTOFactory.sol`: The contract that creates the token pair.
- `YexFTOPair.sol`: The contract that manages the token pair transactions.

## Where is the FTO model going to be used?

The FTO model is going to be used by Honeypot Finance, which is the DeFi Hub that integrates a unique AMM model to unite a community-led launchpad and DEX, addressing Defi's low liquidity utilization issues.
