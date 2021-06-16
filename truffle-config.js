require('dotenv').config();

const HDWalletProvider = require('@truffle/hdwallet-provider');

module.exports = {
  networks: {
    development: {
      network_id: '*',
      host: 'localhost',
      port: process.env.PORT
    },
    main: {
      provider: function() {
        return new HDWalletProvider(
          //private keys array
          process.env.MNEMONIC,
          //url to ethereum node
          process.env.WEB3_PROVIDER_ADDRESS
        )
      },
      network_id: 1,
      gas: process.env.GAS,
      gasPrice: process.env.GAS_PRICE,
      confirmations: 2,
      websockets: true
    },
    kovan: {
      provider: function() {
        return new HDWalletProvider({
          mnemonic: process.env.MNEMONIC,
          providerOrUrl: process.env.WEB3_PROVIDER_ADDRESS,
          chainId: 42
        })
      },
      network_id: 42,
      gas: process.env.GAS,
      gasPrice: process.env.GAS_PRICE,
      confirmations: 0,
      websockets: true,
      skipDryRun: true
    }
  },
  compilers: {
    solc: {
      version: "0.8.0",
    }
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    etherscan: process.env.ETHERSCAN_API
  }
};