const ChefLink = artifacts.require("ChefLink");
const BN = require("bn.js")
module.exports = async function (done) {
    cl = await ChefLink.deployed()
    const LPT = "0x06a69Af8008e80a6729636c9Fc5AFba2a25b541C" // LPT test on goerli
    const allocPoint = 10000
    const tx = await cl.add(allocPoint, LPT, true, { gas: 150000 })
    console.log(tx.tx)
    done()
};
