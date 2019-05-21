const LptOrderBook = artifacts.require("LptOrderBook")
const ControllerMock = artifacts.require('ControllerMock')
const BondingManagerMock = artifacts.require('BondingManagerMock')
const RoundsManagerMock = artifacts.require('RoundsManagerMock')
const TestErc20 = artifacts.require('TestErc20')

const BN = require('bn.js')
const {assertEqualBN, assertRevertLocal, assertRevertTestnet} = require('./helpers')
const {advanceBlock, latestBlock} = require('openzeppelin-test-helpers/src/time')

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
const RINKEBY_BONDING_MANAGER_ADDRESS = '0x37dC71366Ec655093b9930bc816E16e6b587F968'
const TEST_NETWORKS = {
    LOCAL: 0,
    RINKEBY: 1,
}

// CHANGE THIS TO SPECIFY LOCAL OR RINKEBY TESTNET
const testnet = TEST_NETWORKS.LOCAL

const contextualIt = testnet === TEST_NETWORKS.LOCAL ? it : it.skip
const contextualDescribe = testnet === TEST_NETWORKS.LOCAL ? describe : describe.skip
const assertRevert = testnet === TEST_NETWORKS.LOCAL ? assertRevertLocal : assertRevertTestnet

const advanceBlocks = async blocks => {
    for (var i = 0; i < blocks; i++) {
        await advanceBlock()
    }
}

const advanceToBlock = async block =>
    await advanceBlocks(block - await latestBlock())

contract('LptOrderBook', ([sellOrderCreator, sellOrderBuyer, notSellOrderBuyer]) => {

    this.roundLengthBlocks = testnet === TEST_NETWORKS.LOCAL ? 2 : 5760
    this.unbondingPeriodRounds = 7
    this.unbondingPeriodBlocks = this.unbondingPeriodRounds * this.roundLengthBlocks

    this.lptSellValue = 30
    this.daiPaymentValue = 20
    this.daiCollateralValue = 10

    beforeEach(async () => {
        this.livepeerToken = await TestErc20.new()
        this.daiToken = await TestErc20.new()

        if (testnet === TEST_NETWORKS.LOCAL) {
            const bondingManager = await BondingManagerMock.new(this.unbondingPeriodRounds)
            const roundsManager = await RoundsManagerMock.new(this.roundLengthBlocks)
            const controller = await ControllerMock.new(this.livepeerToken.address, bondingManager.address, roundsManager.address)
            this.lptOrderBook = await LptOrderBook.new(controller.address, this.daiToken.address)

        } else if (testnet === TEST_NETWORKS.RINKEBY) {
            this.lptOrderBook = await LptOrderBook.new(RINKEBY_BONDING_MANAGER_ADDRESS, this.daiToken.address)
        }
    })

    describe('createLptSellOrder(lptSellValue, daiPaymentValue, daiCollateralValue, deliveredByBlock)', () => {

        beforeEach(async () => {
            this.deliveredByBlock = (await latestBlock()).add(new BN(this.unbondingPeriodBlocks + 10))
            await this.daiToken.approve(this.lptOrderBook.address, this.daiCollateralValue)
            await this.lptOrderBook.createLptSellOrder(this.lptSellValue, this.daiPaymentValue, this.daiCollateralValue, this.deliveredByBlock)
        })

        it('creates correct LPT sell order', async () => {
            const {
                lptSellValue,
                daiPaymentValue,
                daiCollateralValue,
                deliveredByBlock,
                buyerAddress
            } = await this.lptOrderBook.lptSellOrders(sellOrderCreator)

            await assertEqualBN(lptSellValue, this.lptSellValue)
            await assertEqualBN(daiPaymentValue, this.daiPaymentValue)
            await assertEqualBN(daiCollateralValue, this.daiCollateralValue)
            await assertEqualBN(deliveredByBlock, this.deliveredByBlock)
            assert.strictEqual(buyerAddress, ZERO_ADDRESS)
        })

        it('reverts on creating a second LPT sell order', async () => {
            await this.daiToken.approve(this.lptOrderBook.address, this.daiCollateralValue)
            await assertRevert(this.lptOrderBook.createLptSellOrder(this.lptSellValue, this.daiPaymentValue,
                this.daiCollateralValue, this.deliveredByBlock), "LPT_ORDER_INITIALISED_ORDER")
        })

        it('reverts when specifying delivered by block to the past', async () => {
            await this.lptOrderBook.cancelLptSellOrder()
            await this.daiToken.approve(this.lptOrderBook.address, this.daiCollateralValue)

            await assertRevert(this.lptOrderBook.createLptSellOrder(this.lptSellValue, this.daiPaymentValue,
                this.daiCollateralValue, await latestBlock()), "LPT_ORDER_DELIVERED_BY_IN_PAST")
        })

        describe('cancelLptSellOrder()', () => {

            it('deletes the sell order', async () => {
                await this.lptOrderBook.cancelLptSellOrder()

                const {
                    lptSellValue,
                    daiPaymentValue,
                    daiCollateralValue,
                    deliveredByBlock,
                    buyerAddress
                } = await this.lptOrderBook.lptSellOrders(sellOrderCreator)
                await assertEqualBN(lptSellValue, 0)
                await assertEqualBN(daiPaymentValue, 0)
                await assertEqualBN(daiCollateralValue, 0)
                await assertEqualBN(deliveredByBlock, 0)
                assert.strictEqual(buyerAddress, ZERO_ADDRESS)
            })

            it('returns dai collateral', async () => {
                const originalDaiBalance = await this.daiToken.balanceOf(sellOrderCreator)
                const expectedDaiBalance = new BN(originalDaiBalance).add(new BN(this.daiCollateralValue))

                await this.lptOrderBook.cancelLptSellOrder()

                const actualDaiBalance = await this.daiToken.balanceOf(sellOrderCreator)
                assert.isTrue(actualDaiBalance.eq(expectedDaiBalance))
            })

            it('can create new sell order', async () => {
                await this.lptOrderBook.cancelLptSellOrder()
                await this.daiToken.approve(this.lptOrderBook.address, this.daiCollateralValue)

                await this.lptOrderBook.createLptSellOrder(this.lptSellValue, this.daiPaymentValue, this.daiCollateralValue, this.deliveredByBlock)

                const {
                    lptSellValue,
                    daiPaymentValue,
                    daiCollateralValue,
                    deliveredByBlock,
                    buyerAddress
                } = await this.lptOrderBook.lptSellOrders(sellOrderCreator)
                await assertEqualBN(lptSellValue, this.lptSellValue)
                await assertEqualBN(daiPaymentValue, this.daiPaymentValue)
                await assertEqualBN(daiCollateralValue, this.daiCollateralValue)
                await assertEqualBN(deliveredByBlock, this.deliveredByBlock)
                assert.strictEqual(buyerAddress, ZERO_ADDRESS)
            })
        })

        describe('commitToBuyLpt(address _sellOrderCreator)', () => {

            beforeEach(async () => {
                await this.daiToken.transfer(sellOrderBuyer, this.daiPaymentValue)
                await this.daiToken.approve(this.lptOrderBook.address, this.daiPaymentValue, {from: sellOrderBuyer})
            })

            it('reverts when there is no sell order', async () => {
                await this.lptOrderBook.cancelLptSellOrder()

                await assertRevert(this.lptOrderBook.commitToBuyLpt(sellOrderCreator, {from: sellOrderBuyer}), "LPT_ORDER_UNINITIALISED_ORDER")
            })

            it('reverts when already committed too', async () => {
                await this.lptOrderBook.commitToBuyLpt(sellOrderCreator, {from: sellOrderBuyer})

                await assertRevert(this.lptOrderBook.commitToBuyLpt(sellOrderCreator), "LPT_ORDER_SELL_ORDER_COMMITTED_TO")
            })

            contextualIt('reverts when within unbonding period', async () => {
                await advanceToBlock(this.deliveredByBlock - 5)

                await assertRevert(this.lptOrderBook.commitToBuyLpt(sellOrderCreator, {from: sellOrderBuyer}), "LPT_ORDER_COMMITMENT_WITHIN_UNBONDING_PERIOD")
            })

            it('transfers the dai to the lptOrderBook contract', async () => {
                const originalDaiBalance = await this.daiToken.balanceOf(this.lptOrderBook.address)
                const expectedDaiBalance = originalDaiBalance.add(new BN(this.daiPaymentValue))

                await this.lptOrderBook.commitToBuyLpt(sellOrderCreator, {from: sellOrderBuyer})

                const actualDaiBalance = await this.daiToken.balanceOf(this.lptOrderBook.address)
                assert.isTrue(actualDaiBalance.eq(expectedDaiBalance))
            })

            it('sets the correct buyer address on the sell order', async () => {
                await this.lptOrderBook.commitToBuyLpt(sellOrderCreator, {from: sellOrderBuyer})

                const {buyerAddress} = await this.lptOrderBook.lptSellOrders(sellOrderCreator)

                assert.strictEqual(buyerAddress, sellOrderBuyer)
            })

            contextualDescribe('claimCollateralAndPayment(address _sellOrderCreator)', () => {

                beforeEach(async () => {
                    await this.lptOrderBook.commitToBuyLpt(sellOrderCreator, {from: sellOrderBuyer})
                })

                it('transfers collateral and payment in dai back to the buy order committer', async () => {
                    const originalDaiBalance = await this.daiToken.balanceOf(sellOrderBuyer)
                    const expectedDaiBalance = originalDaiBalance.add(new BN(this.daiPaymentValue + this.daiCollateralValue))
                    await advanceToBlock(this.deliveredByBlock)

                    await this.lptOrderBook.claimCollateralAndPayment(sellOrderCreator, {from: sellOrderBuyer})

                    const actualDaiBalance = await this.daiToken.balanceOf(sellOrderBuyer)
                    assert.isTrue(actualDaiBalance.eq(expectedDaiBalance))
                })

                it("reverts if deliveredByBlock hasn't passed yet", async () => {
                    await advanceToBlock(this.deliveredByBlock - 1)

                    await assertRevert(this.lptOrderBook.claimCollateralAndPayment(sellOrderCreator, {from: sellOrderBuyer}), "LPT_ORDER_STILL_WITHIN_LOCK_PERIOD")
                })

                it('reverts if not called by buyer of a sell order', async () => {
                    await advanceToBlock(this.deliveredByBlock)

                    await assertRevert(this.lptOrderBook.claimCollateralAndPayment(sellOrderCreator, {from: notSellOrderBuyer}), "LPT_ORDER_NOT_BUYER")
                })
            })

            contextualDescribe('fulfillSellOrder()', () => {

                beforeEach(async () => {
                    await this.livepeerToken.approve(this.lptOrderBook.address, this.lptSellValue)
                })

                it('transfers collateral and payment to seller and lpt to buyer', async () => {
                    const originalBuyerDaiBalance = await this.daiToken.balanceOf(sellOrderCreator)
                    const expectedBuyerDaiBalance = originalBuyerDaiBalance.add(new BN(this.daiPaymentValue + this.daiCollateralValue))
                    const originalSellerLptBalance = await this.livepeerToken.balanceOf(sellOrderBuyer)
                    const expectedSellerLptBalance = originalSellerLptBalance.add(new BN(this.daiPaymentValue + this.daiCollateralValue))
                    await this.lptOrderBook.commitToBuyLpt(sellOrderCreator, {from: sellOrderBuyer})

                    await this.lptOrderBook.fulfillSellOrder()

                    const actualBuyerDaiBalance = await this.daiToken.balanceOf(sellOrderCreator)
                    const actualSellerLptBalance = await this.livepeerToken.balanceOf(sellOrderBuyer)
                    assert.isTrue(actualBuyerDaiBalance.eq(expectedBuyerDaiBalance))
                    assert.isTrue(actualSellerLptBalance.eq(expectedSellerLptBalance))
                })

                it('deletes the sell order', async () => {
                    await this.lptOrderBook.commitToBuyLpt(sellOrderCreator, {from: sellOrderBuyer})

                    await this.lptOrderBook.fulfillSellOrder()

                    const {
                        lptSellValue,
                        daiPaymentValue,
                        daiCollateralValue,
                        deliveredByBlock,
                        buyerAddress
                    } = await this.lptOrderBook.lptSellOrders(sellOrderCreator)
                    await assertEqualBN(lptSellValue, 0)
                    await assertEqualBN(daiPaymentValue, 0)
                    await assertEqualBN(daiCollateralValue, 0)
                    await assertEqualBN(deliveredByBlock, 0)
                    assert.strictEqual(buyerAddress, ZERO_ADDRESS)
                })

                it('reverts if there is no buyer', async () => {
                    await assertRevert(this.lptOrderBook.fulfillSellOrder(), "LPT_ORDER_SELL_ORDER_NOT_COMMITTED_TO")
                })
            })
        })
    })
})