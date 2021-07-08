const ChefLink = artifacts.require("ChefLink");
const BN = require("bn.js")
module.exports = async function (done) {
    cl = await ChefLink.deployed()
    const swingby = "0xfcd51b56e65605c33024a9e98a7aadff2e1a15b9" // swingby on goerli
    // const swingby = "0x8287c7b963b405b7b8d467db9d79eec40625b13a" // swingby on mainnet
    const swingbyPerBlock = new BN(4).mul(new BN(10).pow(new BN(18)))
    const startBlock = 5087750
    const bonusEndBlock = startBlock
    const farmCoin = "0xfcd51b56e65605c33024a9e98a7aadff2e1a15b9" // swingby on goerli testnet 
    const farmContract = "0xBCF17C031Ea9C39261E345e65c8f60cAbdb1CD5A"
    const ppid = 0
    const tx = await cl.init(swingby, swingbyPerBlock, startBlock, bonusEndBlock, farmCoin, farmContract, ppid, { gas: 208000 })
    console.log(tx.tx)
    done()
};
