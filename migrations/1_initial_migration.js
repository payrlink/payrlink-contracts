var fs = require('fs');

var Ownable = artifacts.require("../contracts/library/Ownable.sol");
var SafeMath = artifacts.require("../contracts/library/SafeMath.sol");
var ReentrancyGuard = artifacts.require("../contracts/library/ReentrancyGuard.sol");
var PAYR = artifacts.require("../contracts/PAYR.sol");
var Crowdsale = artifacts.require("../contracts/Crowdsale.sol");
var Presale = artifacts.require("../contracts/Presale.sol");

const configs = require("../config.json");

module.exports = async function(deployer) {
  try {
    let dataParse = {};

    const startOfPresale = Math.floor(Date.UTC(2021, 3, 1, 0, 0, 0) / 1000);
    const endOfPresale = Math.floor(Date.UTC(2021, 3, 2, 0, 0, 0) / 1000);
    const startOfICO = Math.floor(Date.UTC(2021, 3, 3, 0, 0, 0) / 1000);
    const endOfICO = Math.floor(Date.UTC(2021, 3, 7, 0, 0, 0) / 1000);

    await deployer.deploy(Ownable, {
      gas: 1000000
    });
    await deployer.link(Ownable, [PAYR, Presale, Crowdsale]);
    dataParse['Ownable'] = Ownable.address;
  
    await deployer.deploy(SafeMath, {
      gas: 1000000
    });
    await deployer.link(SafeMath, [Presale, Crowdsale]);
    dataParse['SafeMath'] = SafeMath.address;
  
    await deployer.deploy(ReentrancyGuard, {
      gas: 1000000
    });
    await deployer.link(ReentrancyGuard, [Presale, Crowdsale]);
    dataParse['ReentrancyGuard'] = ReentrancyGuard.address;
  
    if (!configs.PAYR) {
      await deployer.deploy(PAYR, {
        gas: 5000000
      });
      await PAYR.deployed();
      dataParse['PAYR'] = PAYR.address;
    }
    else {
      dataParse['PAYR'] = configs.PAYR;
    }
  
    if (!configs.Presale) {
      await deployer.deploy(Presale, dataParse['PAYR'], startOfPresale, endOfPresale, endOfICO, {
        gas: 5000000
      });
      dataParse['Presale'] = Presale.address;
    }
    else {
      dataParse['Presale'] = configs.Presale;
    }
  
    if (!configs.Crowdsale) {
      await deployer.deploy(Crowdsale, dataParse['PAYR'], startOfICO, endOfICO, {
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
