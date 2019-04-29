# LPTFutures

## Context

The Livepeer Token (LPT) is an ERC-20 Token on Ethereum.

Livepeer's Protocol provides incentives to LPT holders to bond these tokens to a node in Livepeer's network.

While tokens are bonded, they cannot be transferred to another address.

In order to transfer to another address, the tokens must first be unbonded.

When a holder unbonds LPT from the node, they must wait for an _unbonding period_ before they can withdraw the LPT.

During this _unbonding period_, the holder does not receive any rewards.

DAI is an ERC-20 Token on Ethereum.

## Starting Situation

Alice has LPT, which is bonded to a node in Livepeer's network. Alice also has DAI.

Bob has DAI.

## Objective

Alice would like to exchange `x` LPT for `y` DAI.

## Use Cases

### Scenario 1 - Failure

1. Alice:

- Defines `x` - the amount of LPT that Alice will provide
- Defines `y` - the amount of DAI Alice will receive in exchange for `x` LPT

- Defines `p` - the block by which Alice promises to provide the LPT

- Deposits `z` DAI - which Alice will lose if she doesn't provide `x` LPT by block `p`

2. Alice withdraws `z` DAI

3. Block `p` is mined

### Scenario 2 - Failure

1. Alice:

- Defines `x` - the amount of LPT that Alice will provide
- Defines `y` - the amount of DAI Alice will receive in exchange for `x` LPT

- Defines `p` - the block by which Alice promises to provide the LPT

- Deposits `z` DAI - which Alice will lose if she doesn't provide `x` LPT by block `p`

2. Bob deposits `y` DAI

3. Block `p` is mined

4. Bob withdraws `y + z` DAI

### Scenario 3 - Success

1. Alice:

- Defines `x` - the amount of LPT that Alice will provide
- Defines `y` - the amount of DAI Alice will receive in exchange for `x` LPT

- Defines `p` - the block by which Alice promises to provide the LPT

- Deposits `z` DAI - which Alice will lose if she doesn't provide `x` LPT by block `p`

2. Bob deposits `y` DAI

3. Alice deposits `x` LPT and receives `y + z` DAI

4. Bob withdraws `x` LPT.
