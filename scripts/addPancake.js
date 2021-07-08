const ChefLink = artifacts.require("ChefLink");
const BN = require("bn.js")
module.exports = async function (done) {
    cl = await ChefLink.deployed()
    const LPT = "0xa88921dc290f888b5ee574cf2cd1599f412f1534" // LPT test on bsc_testnet
    const allocPoint = 10000
    const tx = await cl.add(allocPoint, LPT, true, { gas: 150000 })
    console.log(tx.tx)
    done()
};
