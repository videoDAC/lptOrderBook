# LPTFutures

This repository is to store designs and implementation of smart contracts for trading LPT which currently exist in a bonded state.

## Context

The Livepeer Token (LPT) is an ERC-20 Token on Ethereum, used to secure the Livepeer Protocol.

Livepeer's Protocol provides incentives to LPT holders to bond these tokens to a node in Livepeer's network.

When a holder unbonds LPT from the node, they must wait for an _unbonding period_ before they can withdraw the LPT.

During this _unbonding period_, the holder does not receive any rewards.

## Starting Situation

Alice has TokenA.

Bob has LPT bonded to a node in Livepeer's network.

Bob also has TokenB.

(TokenA and TokenB can be the same).

## Objective

Alice would like to exchange `x` TokenA for `y` LPT.

## Main Success Scenario

1. Alice deposits `x` TokenA into the contract, specifying

* `y` = the amount of LPT to be received in exchange for `x` TokenA
* `z` = the amount of TokenB to be provided as security, and
* `t` = the time by which the LPT must be delivered.

2. Bob deposits `z` TokenB.

3. Bob deposits `y` LPT _before_ time `t`, and receives `x` TokenA and `z` TokenB.

4. Alice withdraws `y` LPT.

## Alternative Scenario 1

1. Alice deposits `x` TokenA into the contract, specifying

* `y` = the amount of LPT to be received in exchange for `x` TokenA
* `z` = the amount of TokenB to be provided as security, and
* `t` = the time when the offer expires

2. Bob deposits `z` TokenB.

3. Alice withdraws `x` TokenA _after_ time `t`, and receives `z` TokenB

## Alternative Scenario 2

1. Alice deposits `x` TokenA into the contract, specifying

* `y` = the amount of LPT to be received in exchange for `x` TokenA
* `z` = the amount of TokenB to be provided as security, and
* `t` = the time when the offer expires

2. Alice withdraws `x` TokenA.
