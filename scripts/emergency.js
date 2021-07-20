const ChefLink = artifacts.require("ChefLink");
const BN = require("bn.js")
module.exports = async function (done) {
    cl = await ChefLink.deployed()
    const pid = 0
    //const tx = await cl.kynkyuJitaiSengenKaijo(pid, { gas: 2300000 })
    const tx = await cl.kynkyuJitaiSengen(pid, { gas: 2300000 })
    console.log(tx.tx)
    done()
};
