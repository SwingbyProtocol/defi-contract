const ChefLink = artifacts.require("ChefLink");
const BN = require("bn.js")
module.exports = async function (done) {
    cl = await ChefLink.deployed()
    const swingby = "0x1d606092b6c14d940bc421884009af9ea6f54c1c" // swingby on bsc_testnet
    // const swingby = "0x8287c7b963b405b7b8d467db9d79eec40625b13a" // swingby on mainnet
    const swingbyPerBlock = new BN(4).mul(new BN(10).pow(new BN(18)))
    const startBlock = 10415559
    const bonusEndBlock = startBlock
    const farmCoin = "0x22dc6cf365476465ca3897dc5a23e7cb0a65a482" // cakes on bsc_testnet 
    const farmContract = "0x22f6de9b90783fa94afb08d34fcfda0ceb07988b"
    const ppid = 1
    const tx = await cl.init(swingby, swingbyPerBlock, startBlock, bonusEndBlock, farmCoin, farmContract, ppid, { gas: 208000 })
    console.log(tx.tx)
    done()
};
