const ChefLink = artifacts.require("ChefLink");
const BN = require("bn.js")
module.exports = async function (done) {
    cl = await ChefLink.at("0xBCF17C031Ea9C39261E345e65c8f60cAbdb1CD5A")
    const LPT = "0x06a69Af8008e80a6729636c9Fc5AFba2a25b541C" // mStable on goerli testnet
    const allocPoint = 5000
    const tx = await cl.add(allocPoint, LPT, true)
    console.log(tx.tx)
    done()
};
