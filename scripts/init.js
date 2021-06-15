const ChefLink = artifacts.require("ChefLink");
const BN = require("bn.js")
module.exports = async function (done) {
    cl = await ChefLink.deployed()
    const swingby = "0xfcd51b56e65605c33024a9e98a7aadff2e1a15b9" // mStable on goerli testnet
    const swingbyPerBlock = new BN(100).mul(new BN(10).pow(new BN(18)))
    const startBlock = 4983920
    const bonusEndBlock = 4993920
    const tx = await cl.init(swingby, swingbyPerBlock, startBlock, bonusEndBlock, { nonce: 20 })
    console.log(tx.tx)
    done()
};
