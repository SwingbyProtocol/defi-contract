const BN = require('bn.js');
const ChefLinkMaki = artifacts.require("ChefLinkMaki");

module.exports = function (deployer) {
  //const stakedToken = "0xbd29762224829f9b72b895515663D57F0D33ca69"
  const stakedToken = "0x22883a3dB06737eCe21F479A8009B8B9f22b6cC9" // mainnet
  //const rewardToken = "0xfcd51b56e65605c33024a9e98a7aadff2e1a15b9"
  const rewardToken = "0x8287c7b963b405b7b8d467db9d79eec40625b13a" // mainnet
  // const swapContract = "0x069a9da3ad85697ab87d67dc99d52d12fa55661d"
  const swapContract = "0xbe83f11d3900F3a13d8D12fB62F5e85646cDA45e" // mainnet
  // const btct = "0xeb47a21c1fc00d1e863019906df1771b80dbe182"
  const btct = "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599" // mainnet
  const rewardPerBlock = new BN(1).mul(new BN(10).pow(new BN(18))) // decimals == 18
  const maxRewardPerBlock = rewardPerBlock.mul(new BN(14)).div(new BN(10))
  const startBlock = 13081678  // mainnet blocks
  const bonusEndBlock = 23091445 // mainnet blocks
  deployer.deploy(ChefLinkMaki, stakedToken, rewardToken, swapContract, btct, rewardPerBlock, maxRewardPerBlock, startBlock, bonusEndBlock);
};
