const BN = require('bn.js');
const ChefLinkMaki = artifacts.require("ChefLinkMaki");

module.exports = function (deployer) {
  const stakedToken = "0xbd29762224829f9b72b895515663D57F0D33ca69"
  const rewardToken = "0xfcd51b56e65605c33024a9e98a7aadff2e1a15b9"
  const swapContract = "0x069a9da3ad85697ab87d67dc99d52d12fa55661d"
  const btct = "0xeb47a21c1fc00d1e863019906df1771b80dbe182"
  const rewardPerBlock = new BN(1).mul(new BN(10).pow(new BN(18))) // decimals == 18
  const maxRewardPerBlock = rewardPerBlock.mul(new BN(14)).div(new BN(10))
  const startBlock = 5307109  // goerli blocks
  const bonusEndBlock = 5317109 // goerli blocks
  deployer.deploy(ChefLinkMaki, stakedToken, rewardToken, swapContract, btct, rewardPerBlock, maxRewardPerBlock, startBlock, bonusEndBlock);
};
