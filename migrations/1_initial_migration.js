var fs = require('fs');

var PAYR = artifacts.require("../contracts/PAYR.sol");
var Crowdsale = artifacts.require("../contracts/Crowdsale.sol");
var Presale = artifacts.require("../contracts/Presale.sol");

const configs = require("../config.json");

module.exports = async function(deployer) {
  try {
    let dataParse = {};

    // const startOfPresale = Math.floor(Date.UTC(2021, 3, 1, 0, 0, 0) / 1000);
    // const endOfPresale = Math.floor(Date.UTC(2021, 3, 2, 0, 0, 0) / 1000);
    const startOfICO = Math.floor(Date.UTC(2021, 5, 4, 0, 0, 0) / 1000);
    const endOfICO = Math.floor(Date.UTC(2021, 5, 22, 0, 0, 0) / 1000);
    const publishDate = Math.floor(Date.UTC(2021, 5, 23, 0, 0, 0) / 1000);

    if (!configs.PAYR) {
      await deployer.deploy(PAYR, {
        gas: 4000000
      });
      let payrInstance = await PAYR.deployed();
      dataParse['PAYR'] = PAYR.address;
      await payrInstance.mint(configs.owner, web3.utils.toBN(configs.mint));
    }
    else {
      dataParse['PAYR'] = configs.PAYR;
    }
  
    // if (!configs.Presale) {
    //   await deployer.deploy(Presale, dataParse['PAYR'], startOfPresale, endOfPresale, endOfICO, {
    //     gas: 5000000
    //   });
    //   dataParse['Presale'] = Presale.address;
    // }
    // else {
    //   dataParse['Presale'] = configs.Presale;
    // }
  
    if (!configs.Crowdsale) {
      await deployer.deploy(Crowdsale, dataParse['PAYR'], startOfICO, endOfICO, publishDate, {
        gas: 5000000
      });
      dataParse['Crowdsale'] = Crowdsale.address;
    }
    else {
      dataParse['Crowdsale'] = configs.Crowdsale;
    }

    const updatedData = JSON.stringify(dataParse);
		await fs.promises.writeFile('contracts.json', updatedData);

  } catch (error) {
    console.log(error);
  }

};
