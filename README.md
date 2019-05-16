# lptDaiFutureOrderBook

## Context

[Livepeer Token](https://etherscan.io/token/0x58b6a8a3302369daec383334672404ee733ab239) (LPT) is an ERC-20 Token on Ethereum. 

[DAI](https://etherscan.io/token/0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359) is another ERC-20 Token on Ethereum.

## Context and Objectives

**Alice** has LPT, which will not become available to her until a specific time in the future. Alice also has DAI.

**Bob** has DAI.

**Alice** would like to exchange `x` LPT for `y` DAI.

## Use Cases

### Scenario 1 - Failure

1. **Alice** creates the order:

- Defines `x` - the amount of LPT that **Alice** will provide
- Defines `y` - the amount of DAI **Alice** will receive in exchange for `x` LPT
- Defines `p` - the block by which **Alice** promises to provide the LPT

- Sends `z` DAI - a deposit which **Alice** will put at risk if she doesn't provide `x` LPT by block `p`

2. **Alice** cancels the order, and withdraws `z` DAI

### Scenario 2 - Failure

1. **Alice** creates the order:

- Defines `x` - the amount of LPT that **Alice** will provide
- Defines `y` - the amount of DAI **Alice** will receive in exchange for `x` LPT
- Defines `p` - the block by which **Alice** promises to provide the LPT
- Sends `z` DAI - a deposit which **Alice** will put at risk if she doesn't provide `x` LPT by block `p`

2. **Bob** fills the order, sending `y` DAI.

3. Block `p` is mined

4. **Bob** withdraws `y + z` DAI

### Scenario 3 - Success

1. **Alice** creates the order:

- Defines `x` - the amount of LPT that **Alice** will provide
- Defines `y` - the amount of DAI **Alice** will receive in exchange for `x` LPT
- Defines `p` - the block by which **Alice** promises to provide the LPT
- Sends `z` DAI - a deposit which **Alice** will put at risk if she doesn't provide `x` LPT by block `p`

2. **Bob** fills the order, sending `y` DAI.

3. **Alice** sends `x` LPT, and receives `y + z` DAI. **Bob** receives `x` LPT.
