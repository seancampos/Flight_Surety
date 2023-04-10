
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  const INSURANCE_PREMIUM_1 = web3.utils.toWei("0.1", "ether");
  const TEST_ORACLES_COUNT = 30;
  const ORACLES_OFFSET = 7;
  const STATUS_CODE_LATE_AIRLINE = 20;

  const flights = [
    {
      timestamp: Math.floor(Date.now() / 1000) + 3600,
      airline: accounts[1],
      flight: "DL0001"
    },
    {
      timestamp: Math.floor(Date.now() / 1000) + 7200,
      airline: accounts[2],
      flight: "UA0002"
    },
    {
      timestamp: Math.floor(Date.now() / 1000) + 10800,
      airline: accounts[3],
      flight: "NZ0003"
    }
  ]

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  describe(`(multiparty) functionality tests`, function()
  {
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
          await config.flightSuretyApp.registerAirline(newAirline, "airline2", {from: config.firstAirline});
      }
      catch(e) {
          // console.log(e);
      }
      let result = await config.flightSuretyData.isAirline(newAirline); 

      // ASSERT
      assert.equal(result, false, "Airline did not have enough funding to reginter another airline.");

    });

    it('(airline) can register the first 4 airlines without multiparty consensus', async () => {
      
      // ARRANGE
      let airline2 = accounts[2];
      let airline3 = accounts[3];
      let airline4 = accounts[4];
      let min_funds = await config.flightSuretyApp.MIN_FUNDS.call();

      // ACT
      try {
          await config.flightSuretyApp.fundAirline(config.firstAirline, {value: min_funds, from: config.firstAirline})
          await config.flightSuretyApp.registerAirline(airline2, "airline2", {from: config.firstAirline});
          await config.flightSuretyApp.registerAirline(airline3, "airline3", {from: config.firstAirline});
          await config.flightSuretyApp.registerAirline(airline4, "airline4", {from: config.firstAirline});
      }
      catch(e) {
          console.log(e);
      }
      let fundamt = await config.flightSuretyData.getAirlineFunds(config.firstAirline);
      let result = await config.flightSuretyData.isAirline(airline2); 
      let registeredAirlineCount = await config.flightSuretyData.getRegisteredAirlinesCount.call()

      // ASSERT
      // assert.equal(funds_check, fundamt, "Airline should have funds credited");
      assert.equal(fundamt.toString(10), min_funds.toString(10), "Airline should have funds in account");
      assert.equal(result, true, "Airline2 should be directly regisitered");
      assert.equal(registeredAirlineCount, 4, "Airline should be able to directly register first 4 airlines")
    });
  });
/*
  describe(`(airline) tests of airline functionality`, function() {
    it('(airline) requires concensus after 4 airlines regisitered', async () => {
      // ARRANGE
      let airline5 = accounts[5];

      // ACT
      try {
          await config.flightSuretyApp.registerAirline(airline5, "airline5", {from: config.firstAirline});
      }
      catch (e) {
          
      }

      // ASSERT
      let airlineFound5 = await config.flightSuretyData.isAirline(airline5);
      let airlineRegistered5 = await config.flightSuretyData.isAirlineRegistered(airline5);
      assert.equal(airlineFound5, true, "Fifth airline should exist");
      assert.equal(airlineRegistered5, false, "Fifth Airline should not be regisitered");
    });

    it('(airline) is approved for registration after majority of funded airlines vote', async () => {
      // ARRANGE
      let airline2 = accounts[2];
      let airline3 = accounts[3];

      let airline5 = accounts[5];

      let voteCount = 0;

      let min_funds = await config.flightSuretyApp.MIN_FUNDS.call();

      // ACT
      try {
          await config.flightSuretyApp.fundAirline(airline2, {value: min_funds, from: airline2});
          await config.flightSuretyApp.fundAirline(airline3, {value: min_funds, from: airline3});
          await config.flightSuretyApp.voteForAirline(airline5, {from: config.firstAirline});
          await config.flightSuretyApp.voteForAirline(airline5, {from: airline2});
          await config.flightSuretyApp.voteForAirline(airline5, {from: airline3});
      }
      catch (e) {
          console.log(e);
      }

      // ASSERT
      let airline5Votes = await config.flightSuretyData.getAirlineVoteCount(airline5)
      let airlineFound5 = await config.flightSuretyData.isAirline(airline5);
      let airlineRegistered5 = await config.flightSuretyData.isAirlineRegistered(airline5);
      assert.equal(airline5Votes, 3, "3 airlines voted for airline5");
      assert.equal(airlineFound5, true, "Fifth airline should exist");
      assert.equal(airlineRegistered5, true, "Fifth Airline be regisitered");
    });
  })

  describe('(flight) test flight functionality', function() {
    it('(flight) can be registered', async () => {
      // ARANGE
      let flight1 = flights[0];
      let flight2 = flights[1];
      // ACT
      try {
        await config.flightSuretyApp.registerFlight(flight1.timestamp, flight1.flight, {from: flight1.airline});
        await config.flightSuretyApp.registerFlight(flight2.timestamp, flight2.flight, {from: flight2.airline});
      }
      catch(e) {
        console.log(e);
      }
      flight1Exists = await config.flightSuretyData.isFlight.call(flight1.timestamp, flight1.airline, flight1.flight);
      assert.equal(flight1Exists, true, "flight1 was regiistered");
      flight2Exists = await config.flightSuretyData.isFlight.call(flight2.timestamp, flight2.airline, flight2.flight);
      assert.equal(flight2Exists, true, "flight2 was regiistered");
      FakeFlightExists = await config.flightSuretyData.isFlight.call(flight2.timestamp, flight2.airline, "XXXXX");
      assert.equal(FakeFlightExists, false, "Fake flight does not exist");
    });

    // it('(flight) cannot register a flight more than once', async () => {
    //   let reverted = false;
    //   try {
    //     await config.flightSuretyApp.registerFlight(flight1.flight, flight1.to, flight1.from, flight1.timestamp, {from: flight1.airline});
    //   }
    //   catch(e) {
    //     //console.log(e);
    //     reverted = true;
    //   }

    //   assert.equal(reverted, true, "Airline cannot register a flight more than once");
    // });

    it('(flight) cannot be registered to an unfunded airline', async () => {
      // ARRANGE
      let flight = flights[2]; // unregistered flight
      let unfundedAirline = accounts[5]; // unfunded airline
      // ACT
      try {
        await config.flightSuretyApp.registerFlight(flight.timestamp, flight.flightr, {from: unfundedAirline});
      }
      catch(e) {

      }
      // ASSERT
      flightExsits = await config.flightSuretyData.isFlight.call(flight.timestamp, unfundedAirline, flight.flight);
      assert.equal(flightExsits, false, "Flight cannot be registered to an unfunded airline");
    });
  });

  describe('(passenger) test passenger functionality', function() {
    it('(passenger) should be able to buy insurance', async () => {
      // ARRANGE
      console.log("accounts", accounts.length);
      let passenger1 = accounts[6];
      let flight = flights[0]; // registered flight
      // ACT
      try {
        await config.flightSuretyApp.buyInsurance(flight.airline, flight.flight, flight.timestamp, {from: passenger1, value: INSURANCE_PREMIUM_1});
      }
      catch(e) {
        console.log(e);
      }
      // ASSERT
      insured = await config.flightSuretyData.isInsured.call(passenger1, flight.airline, flight.flight, flight.timestamp);
      assert.equal(insured, true, "Passenger is able to buy insurance");
    });

    it('(passenger) should only be able to buy insurance on registered flights', async () => {
      // ARRANGE
      let passenger1 = accounts[6];
      // let passenger2 = accounts[7];
      let flight = flights[2]; // unregistered flight
      // ACT
      try {
        await config.flightSuretyApp.buyInsurance(flight.airline, flight.flight, flight.timestamp, {from: passenger1, value: INSURANCE_PREMIUM_1});
      }
      catch(e) {
        // console.log(e);
      }
      // ASSERT
      insured = await config.flightSuretyData.isInsured(passenger1, flight.airline, flight.flight, flight.timestamp);
      assert.equal(insured, false, "Flight is not registered");
    });

    it('(passenger) cannot buy insurance without funds', async () => {
      // ARRANGE
      let passenger2 = accounts[7];
      let flight = flights[0]; // registered flight
      // ACT
      try {
        await config.flightSuretyApp.buyInsurance(flight.airline, flight.flight, flight.timestamp, {from: passenger2, value: 0});
      }
      catch(e) {
        // console.log(e);
      }
      // ASSERT
      insured = await config.flightSuretyData.isInsured(passenger2, flight.airline, flight.flight, flight.timestamp);
      assert.equal(insured, false, "Passenger is not insured on flight");
    });
  });

  
  describe('(oracles) test oracles functionality', function() {
    it('(oracles) can register oracles', async () => {
      let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

      for(let a=1; a<TEST_ORACLES_COUNT; a++) {

        await config.flightSuretyApp.registerOracle({from: accounts[a+ORACLES_OFFSET], value: fee});
        let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a+ORACLES_OFFSET]});
        console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
      }
    });

    it('(oracles) can request flight status', async () => {
      // ARRANGE
      let flight = flights[0];
      
      // Submit a request for oracles to get status information for a flight
      await config.flightSuretyApp.fetchFlightStatus(flight.airline, flight.flight, flight.timestamp);

      // Since the Index assigned to each test account is opaque by design
      // loop through all the accounts and for each account, all its Indexes (indices?)
      // and submit a response. The contract will reject a submission if it was
      // not requested so while sub-optimal, it's a good test of that feature
      for(let a=1; a<TEST_ORACLES_COUNT; a++) {
        // Get oracle information
        let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a+ORACLES_OFFSET]});
        // console.log('oracleIndexs', oracleIndexes);
        for(let idx=0;idx<3;idx++) {
          try {
            // Submit a response...it will only be accepted if there is an Index match
            await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], flight.airline, flight.flight, flight.timestamp, STATUS_CODE_LATE_AIRLINE, {from: accounts[a+ORACLES_OFFSET]});
          }
          catch(e) {
            // Enable this when debugging
            // console.log('\nError', idx, oracleIndexes[idx].toNumber(), flight.flight, flight.timestamp);
          }
        }
      }
    });

    it('(oracles) flight status code set correctly', async () => {
      // ARRANGE
      let passenger1 = accounts[6];
      let flight = flights[0];
      // ACT
      let passengerOriginalBalance = await web3.eth.getBalance(passenger1);
      let receipt = await config.flightSuretyData.pay({from: passenger1});
      let passengerFinalBalance = await web3.eth.getBalance(passenger1);
      // ASSERT
      
      assert.equal(passengerFinalBalance, passengerOriginalBalance, "Insurance is paid");
      
    });
  
    
  });
/*
  describe('(insurance) test the insurance functionality', function() {
    it('(insurance) insured amount credited is multiplied by the configured multiplier', async () => {
      let amount1 = await config.flightSuretyData.getPendingPaymentAmount(passenger1);
      let amount2 = await config.flightSuretyData.getPendingPaymentAmount(passenger2);
      let multiplier = 1.5;
      assert.equal(amount1, PASSENGER_INSURANCE_VALUE_1 * 1.5, "Insurance amount not as expected");
      assert.equal(amount2, PASSENGER_INSURANCE_VALUE_2 * 1.5, "Insurance amount not as expected");
    });
  
      it('(insurance) payout can be withdrawn by passender', async () => {
        let amount1 = await config.flightSuretyData.getPendingPaymentAmount(passenger1);
        let balanceBeforePay1 = await web3.eth.getBalance(passenger1);
  
        let amount2 = await config.flightSuretyData.getPendingPaymentAmount(passenger2);
        let balanceBeforePay2 = await web3.eth.getBalance(passenger2);
  
        try {
          await config.flightSuretyApp.pay({from: passenger1, gasPrice: 0});
          await config.flightSuretyApp.pay({from: passenger2, gasPrice: 0});
        } catch (e) {
          console.log(e);
        }
        let balanceAfterPay1 = await web3.eth.getBalance(passenger1);
        let balanceAfterPay2 = await web3.eth.getBalance(passenger2);
  
        //console.log('1) Balance before pay: ' + balanceBeforePay1);
        //console.log('1) Balance afer pay: ' + balanceAfterPay1);
        //console.log('1) Difference: ' + (balanceAfterPay1 - balanceBeforePay1));
        //console.log('2) Balance before pay: ' + balanceBeforePay2);
        //console.log('2) Balance afer pay: ' + balanceAfterPay2);
        //console.log('2) Difference: ' + (balanceAfterPay2 - balanceBeforePay2));
  
        assert.equal((balanceAfterPay1 - balanceBeforePay1), amount1, "Cannot withdraw insurance from account");
        assert.equal((balanceAfterPay2 - balanceBeforePay2), amount2, "Cannot withdraw insurance from account");
      });
    });
  });
*/
});
