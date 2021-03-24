var fs = require('fs');

var Farm = artifacts.require("../contracts/Farm.sol");
var PAYR = artifacts.require("../contracts/PAYR.sol");

const configs = require("../config.json");
const contracts = require("../contracts.json");

module.exports = async function(deployer) {
  try {
    let dataParse = contracts;

    if (!configs.Farm) {
      const currentBlock = await web3.eth.getBlockNumber();
      const startBlock = configs.farm_param.startBlock
          || web3.utils.toBN(currentBlock).add(web3.utils.toBN(configs.farm_param.delay));

      await deployer.deploy(Farm, dataParse['PAYR'], web3.utils.toBN(configs.farm_param.rewardPerBlock), startBlock, {
        gas: 5000000
      });
      const farmInstance = await Farm.deployed();
      dataParse['Farm'] = Farm.address;

      if (configs.farm_param.fund) {
        const payrInstance = await PAYR.at(dataParse['PAYR']);
        await payrInstance.approve(Farm.address, web3.utils.toBN(configs.farm_param.fund));
        await farmInstance.fund(web3.utils.toBN(configs.farm_param.fund));
      }

      configs.farm_param.lp.forEach(async (token) => {
        if (token.address) {
          await farmInstance.add(
            token.allocPoint,
            token.address,
            false
          );
        }
      })
    }
    else {
      dataParse['Farm'] = configs.Farm;
    }

    const updatedData = JSON.stringify(dataParse);
		await fs.promises.writeFile('contracts.json', updatedData);

  } catch (error) {
    console.log(error);
  }

};
