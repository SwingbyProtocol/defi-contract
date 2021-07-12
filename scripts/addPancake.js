const ChefLink = artifacts.require("ChefLink");
const BN = require("bn.js")
module.exports = async function (done) {
    cl = await ChefLink.deployed()
    const LPT = "0xa88921dc290f888b5ee574cf2cd1599f412f1534" // LPT test on bsc_testnet
    const allocPoint = 10000
    const farmCoin = "0x22dc6cf365476465ca3897dc5a23e7cb0a65a482" // cakes on bsc_testnet 
    const farmContract = "0x22f6de9b90783fa94afb08d34fcfda0ceb07988b"
    const ppid = 1
    const tx = await cl.add(allocPoint, LPT, farmCoin, farmContract, ppid, true, { gas: 150000 })
    console.log(tx.tx)
    done()
};
