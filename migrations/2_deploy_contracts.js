const LptOrderBook = artifacts.require('LptOrderBook')
const TestErc20 = artifacts.require('TestErc20')

const LIVEPEER_CONTROLLER = '0x37dC71366Ec655093b9930bc816E16e6b587F968'
const DAI_TOKEN = '0x8f2e097E79B1c51Be9cBA42658862f0192C3E487'

module.exports = async (deployer) => {

    //await deployer.deploy(TestErc20)
    // await deployer.deploy(LptOrderBook, LIVEPEER_CONTROLLER, TestErc20.address)

    await deployer.deploy(LptOrderBook, LIVEPEER_CONTROLLER, DAI_TOKEN)
}
