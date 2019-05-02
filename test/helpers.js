const assertEqualBN = async (actualPromise, expected, message) =>
    assert.equal((await actualPromise).toNumber(), expected, message)

const assertRevertLocal = async (receiptPromise, reason) => {
    try {
        await receiptPromise
    } catch (error) {
        if (reason) {
            assert.include(error.message, reason, 'Incorrect revert reason')
        }
        return
    }
    assert.fail(`Expected a revert for reason: ${reason}`)
}

const assertRevertTestnet = async (receiptPromise, reason) => {

    const INCORRECT_STATUS = 'Incorrect receipt status'

    try {
        const receipt = await receiptPromise
        assert.isFalse(receipt.receipt.status, INCORRECT_STATUS)
    } catch (error) {
        if (error.message.includes(INCORRECT_STATUS)) {
            throw error
        }
    }
}

module.exports = {
    assertEqualBN: assertEqualBN,
    assertRevertLocal: assertRevertLocal,
    assertRevertTestnet: assertRevertTestnet
}