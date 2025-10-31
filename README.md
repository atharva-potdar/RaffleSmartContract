# Raffle Smart Contract

This is a smart contract that acts like a simple raffle, allowing users to stake their money. A random user is then selected as the winner and receives the pooled money.

This project is licensed under GPL-v3.0-only and uses:

- Solidity 0.8.30
- [cyfrin/foundry-devops](https://github.com/cyfrin/foundry-devops) 0.4.0
- [smartcontractkit/chainlink-brownie-contracts](https://github.com/smartcontractkit/chainlink-brownie-contracts) 1.3.0
- [foundry-rs/forge-std](https://github.com/foundry-rs/forge-std) 1.11.0
- [Vectorized/solady](https://github.com/Vectorized/solady) 0.1.26

## Build

```
forge build
```

## Test

```
forge test
```

A Makefile is included to make the development workflow easier.
