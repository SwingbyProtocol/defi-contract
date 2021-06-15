const ChefLink = artifacts.require("ChefLink");
const BN = require("bn.js")
module.exports = async function (done) {
    cl = await ChefLink.deployed()
    const swingby = "0xfcd51b56e65605c33024a9e98a7aadff2e1a15b9" // mStable on goerli testnet
    const swingbyPerBlock = new BN(100).mul(new BN(10).pow(new BN(18)))
    const startBlock = 29999
    const bonusEndBlock = 28888
    const tx = await cl.init(swingby, swingbyPerBlock, startBlock, bonusEndBlock)
    console.log(tx.tx)
    done()
};
