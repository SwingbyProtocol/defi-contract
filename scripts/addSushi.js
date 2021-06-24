const ChefLink = artifacts.require("ChefLink");
const BN = require("bn.js")
module.exports = async function (done) {
    cl = await ChefLink.at("0x9520D443a04C3252e5FfBEFCD3E976eeb6C4509f")
    const LPT = "0x4a9c7b98c1a92db0ad33b31b549fb1820fe571ff" // Sushi swap LPT
    const allocPoint = 10000
    const tx = await cl.add(allocPoint, LPT, true, { gas: 150000 })
    console.log(tx.tx)
    done()
};
