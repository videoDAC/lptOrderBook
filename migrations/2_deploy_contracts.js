const LptOrderBook = artifacts.require('LptOrderBook')
const TestErc20 = artifacts.require('TestErc20')

const LIVEPEER_CONTROLLER = '0x37dC71366Ec655093b9930bc816E16e6b587F968'
const DAI_TOKEN = '0x8f2e097E79B1c51Be9cBA42658862f0192C3E487'
const TEST_TOKEN = '0x8900f4B3941d9A45adaD26979271D0A1a314d36b'

module.exports = async (deployer) => {

    //await deployer.deploy(TestErc20)
    await deployer.deploy(LptOrderBook, LIVEPEER_CONTROLLER, TEST_TOKEN)

    // await deployer.deploy(LptOrderBook, LIVEPEER_CONTROLLER, DAI_TOKEN)
}
