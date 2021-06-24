const ChefLink = artifacts.require("ChefLink");
const BN = require("bn.js")
module.exports = async function (done) {
    cl = await ChefLink.at("0x9520D443a04C3252e5FfBEFCD3E976eeb6C4509f")
    const LPT = "0x9E79cCAACAAA5dBB6714EEA8FdFD6496C9618F40" // Uni swap LPT
    const allocPoint = 10000
    const tx = await cl.add(allocPoint, LPT, true, { gas: 150000 })
    console.log(tx.tx)
    done()
};
