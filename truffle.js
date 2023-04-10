// var HDWalletProvider = require("@truffle/hdwallet-provider");
var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost
      port: 8545,            // Standard Ganache UI port
      network_id: "*", 
      gas: 4600000
    },
    test: {
      network_id: '*',
      accounts: 50,
    },
  },
  compilers: {
    solc: {
      version: "0.5.0"
    }
  }
};