var fs = require('fs');

var PAYRLINK = artifacts.require("../contracts/PayrLink.sol");
var ETHFactory = artifacts.require("../contracts/ETHFactory.sol");
var ERC20Factory = artifacts.require("../contracts/ERC20Factory.sol");

const configs = require("../config.json");
const contracts = require("../contracts.json");

module.exports = async function(deployer) {
  try {
    let dataParse = contracts;
    let payrlinkInstance = null;

    if (!configs.PAYRLINK) {
      await deployer.deploy(PAYRLINK, dataParse['PAYR'], {
        gas: 5000000
      });
      payrlinkInstance = await PAYRLINK.deployed();
      dataParse['PAYRLINK'] = PAYRLINK.address;
    }
    else {
      dataParse['PAYRLINK'] = configs.PAYRLINK;
    }

    if (!configs.ETH_FACTORY) {
      await deployer.deploy(ETHFactory, "ETH", dataParse['PAYRLINK'], {
        gas: 5000000
      });
      dataParse['ETH_FACTORY'] = ETHFactory.address;

      await payrlinkInstance.addEthPool(dataParse['ETH_FACTORY'], true);
    }
    else {
      dataParse['ETH_FACTORY'] = configs.ETH_FACTORY;
    }

    if (!configs.DAI_FACTORY) {
      await deployer.deploy(ERC20Factory, configs.DAI, "DAI", dataParse['PAYRLINK'], {
        gas: 5000000
      });
      dataParse['DAI_FACTORY'] = ERC20Factory.address;

      await payrlinkInstance.addERC20Pool(configs.DAI, dataParse['DAI_FACTORY'], true);
    }
    else {
      dataParse['DAI_FACTORY'] = configs.DAI_FACTORY;
    }

    const updatedData = JSON.stringify(dataParse);
		await fs.promises.writeFile('contracts.json', updatedData);

  } catch (error) {
    console.log(error);
  }

};
