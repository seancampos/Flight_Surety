
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  const MIN_FUNDS = web3.utils.toWei("10", "ether");

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) can register the first 4 airlines without multiparty consensus', async () => {
    
    // ARRANGE
    let airline2 = accounts[2];
    let airline3 = accounts[3];
    let airline4 = accounts[4];

    // ACT
    try {
        let funds_check = await config.flightSuretyApp.fundAirline(config.firstAirline, {value: MIN_FUNDS, from: config.firstAirline, gas: 999999})
        // assert.equal(funds_check, MIN_FUNDS, "Airline should have funds credited");
        await config.flightSuretyApp.registerAirline(airline2, {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(airline3, {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(airline4, {from: config.firstAirline});
    }
    catch(e) {
        console.log(e);
    }
    let fundamt = await config.flightSuretyData.getAirlineFunds.call(config.firstAirline);
    let result = await config.flightSuretyData.isAirline.call(airline4); 
    let registeredAirlineCount = await config.flightSuretyData.getRegisteredAirlinesCount.call()

    // ASSERT
    // assert.equal(funds_check, fundamt, "Airline should have funds credited");
    
    assert.equal(result, true, "Airline should be able to directly register first 4 airlines");
    assert.equal(registeredAirlineCount, 4, "Airline should be able to directly register first 4 airlines")
    assert.equal(fundamt, MIN_FUNDS, "Airline should have funds in account");

  });
 

});
