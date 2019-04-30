const assertEqualBN = async (actualPromise, expected, message) =>
    assert.equal((await actualPromise).toNumber(), expected, message)

const assertRevert = async (receiptPromise, reason) => {
    try {
        await receiptPromise
    } catch (e) {
        if (reason) {
            assert.include(e.message, reason, 'Incorrect revert reason')
        }
        return
    }
    assert.fail(`Expected a revert for reason: ${reason}`)
}

module.exports = {
    assertEqualBN: assertEqualBN,
    assertRevert: assertRevert
}