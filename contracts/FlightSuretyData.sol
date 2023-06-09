pragma solidity >=0.4.25 <0.6.0;

import "../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    // App Contracts
    mapping(address => bool) private authorizedContracts;

    // Airline satus codes
    uint8 private constant UNREGISTERED = 0; // empty value
    uint8 private constant PENDING = 10;
    uint8 private constant REGISTERED = 20;
    // Airline struct
    struct Airline {
        string name;
        uint8 status;
        uint256 funds;
    }
    // collection of airlines
    mapping(address => Airline) private airlines;
    // airline count
    uint256 public registeredAirlinesCount;
    // airline votes
    mapping(address => address[]) private airlineVotes;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    // Flight Struct
    struct Flight {
        bool registered;
        uint256 timestamp;
        uint8 status;
        address airline;
        string flight;
    }
    // mapping flightKey to Flight
    mapping(bytes32 => Flight) private flights;
    
    // Insurance Struct
    struct Insurance {
        address passenger;
        uint256 premium; // Passenger insurance payment
        uint256 payAmount; // General damages multiplier (1.5x by default)
        bool paid;
    }
    // mapping flightKey to array of policies
    mapping (bytes32 => Insurance[]) flightInsurancePolicies;
    // mapping of payee addresses and balances
    mapping (address => uint256) public payouts;
    

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    // Event fired each time a policy is credited to a passender
    event CreditIssued(address airline, string flight, uint256 timestamp, address passenger, uint256 payamount);

    event PassengerPayout(address passenger, uint256 amount);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address firstAirlineAddress,
                                    string memory firstAirlineName
                                )
                                public
                                payable 
    {
        contractOwner = msg.sender;

         // Deploy first airline when contract is deployed
        airlines[firstAirlineAddress] = Airline({
            name: firstAirlineName,
            status: REGISTERED,
            funds: 0
        });
        registeredAirlinesCount = 1;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * Requires authorized address to make a call
    */
    modifier requireIsAuthorized() {
        require(authorizedContracts[msg.sender], "Caller is not authorized");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /**
    * Check if an airline is registered
    *
    */      
    function isAirline(address airlineAddress) 
                            public 
                            view
                            returns(bool) 
    {
        return airlines[airlineAddress].status != UNREGISTERED;
    }

    /**
    * Authorize app contracts
    */  
    function authorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        authorizedContracts[contractAddress] = true;
    }

    /* get count of airlines */
    function getRegisteredAirlinesCount() public view returns(uint256) {
        return registeredAirlinesCount;
    }

    /* get airline status */
    function getAirlineStatus(address airlineAddress) public view returns(uint8) {
        return airlines[airlineAddress].status;
    }

    /* get airline funds */
    function getAirlineFunds(address airlineAddress) public view returns(uint256) {
        return airlines[airlineAddress].funds;
    }

    /* get vote count */
    function getAirlineVoteCount(address airlineAddress) external view returns(uint256) {
        return airlineVotes[airlineAddress].length;
    }

    /* check if airline is registered */
    function isAirlineRegistered(address airlineAddress) external view returns(bool) {
        return airlines[airlineAddress].status == REGISTERED;
    }

    /* compute hash for flight number key */
    // function getFlightKey(uint256 timestamp, address airline, string calldata flight) pure internal returns(bytes32) {
    //     return keccak256(abi.encodePacked(timestamp, airline, flight));
    // }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /* Check if an airline is registered */
    function isFlight(uint256 timestamp, address airline, string memory flight) 
                            public
                            view
                            returns(bool) 
    {
        return flights[getFlightKey(airline, flight, timestamp)].registered;
    }

    /* check if passenger has an insurance policy for a flight */
    function isInsured(address passenger, address airline, string calldata flight, uint256 timestamp) external view returns(bool)
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        // Insurance[] calldata flightPolicies = flightInsurancePolicies[flightKey];
        // if (flightInsurancePolicies[flightKey] == address(0)) {
        //     return false;
        // }
        for(uint256 i = 0; i < flightInsurancePolicies[flightKey].length; i++) {
            if (flightInsurancePolicies[flightKey][i].passenger == passenger) {
                return true;
            }
        }
        return false;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (   
                                address airlineAddress,
                                string calldata airlineName,
                                uint8 airlineStatus
                            )
                            external
                            requireIsOperational
                            requireIsAuthorized
    {
        require(airlineAddress != address(0), "Airline must have a valid wallet.");
        airlines[airlineAddress] = Airline({
            name: airlineName,
            status: airlineStatus,
            funds: 0
        });
        if (airlineStatus == REGISTERED) {
            registeredAirlinesCount++;
        }
    }

    function approveAirline
                            (
                                address airlineAddress
                            )
                            external
                            requireIsOperational
                            requireIsAuthorized
    {
        airlines[airlineAddress].status = REGISTERED;
        registeredAirlinesCount++;
    }

    function fundAirline
                            (
                                address airlineAddress,
                                uint256 funds
                            )
                            external
                            requireIsOperational
                            requireIsAuthorized
                            returns(uint256)
    {
        
        uint256 currentFunds = airlines[airlineAddress].funds;
        currentFunds = currentFunds.add(funds);
        airlines[airlineAddress].funds = currentFunds;
        return currentFunds;
    }

    function voteForAirline(address votingAirlineAddress, address airlineAddress) external requireIsOperational
    {    
        // make sure that each airline only votes once
        uint256 voteCounter = airlineVotes[airlineAddress].length;
        if (voteCounter == 0) {
            airlineVotes[airlineAddress] = new address[](0);
        }
        // check for double voting
        uint256 i = 0;
        for (; i < voteCounter; i++) {
            if (airlineVotes[airlineAddress][i] == votingAirlineAddress) {
                break;
            }
        }
        // no double voting if msg.sender not found
        if (i == voteCounter) {
            airlineVotes[airlineAddress].push(msg.sender);
        }
    }

    function registerFlight
                                (
                                    uint256 timestamp,
                                    address airline,
                                    string calldata flight
                                )
                                external
                                requireIsOperational
                                requireIsAuthorized
    {   
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        require(!flights[flightKey].registered, "Flight has alerady been registered.");
        flights[flightKey] = Flight({
            registered: true,
            status: STATUS_CODE_UNKNOWN,
            timestamp: timestamp,
            airline: airline,
            flight: flight
        });
    }

    function setFlightStatus
                            (
                                address airline,
                                string calldata flight,
                                uint256 timestamp,
                                uint8 statusCode
                            )
                            external
                            requireIsOperational
                            requireIsAuthorized
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        require(flights[flightKey].registered, "Flight must be registered.");
        flights[flightKey].status = statusCode;
    }
    
   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (
                                address passenger,
                                address airline,
                                string calldata flight,
                                uint256 timestamp,
                                uint256 premium,
                                uint256 multiplier 
                            )
                            external
                            requireIsOperational
                            requireIsAuthorized
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        uint256 payAmount = premium.mul(multiplier).div(100);
        flightInsurancePolicies[flightKey].push(Insurance({
            passenger: passenger,
            premium: premium,
            payAmount: payAmount,
            paid: false
        }));
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address airline,
                                    string calldata flight,
                                    uint256 timestamp
                                )
                                external
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        for (uint256 i = 0; i < flightInsurancePolicies[flightKey].length; i++) {
            Insurance memory policy = flightInsurancePolicies[flightKey][i];
            if (policy.paid == false) {
                policy.paid = true;
                payouts[flightInsurancePolicies[flightKey][i].passenger] = payouts[flightInsurancePolicies[flightKey][i].passenger].add(flightInsurancePolicies[flightKey][i].payAmount);
                emit CreditIssued(airline, flight, timestamp, flightInsurancePolicies[flightKey][i].passenger, flightInsurancePolicies[flightKey][i].payAmount);
            }
        }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            payable
                            external
    {
        uint256 payout = payouts[msg.sender];
        if (payout > 0) {
            payouts[msg.sender] = 0;
            address(uint160(address(msg.sender))).transfer(payout);
            emit PassengerPayout(msg.sender, payout);
        }
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
                            requireIsOperational
    {
        uint256 currentFunds = airlines[msg.sender].funds;
        airlines[msg.sender].funds = currentFunds.add(msg.value);
    }

    function getBalance(
        address passenger
    ) external view returns(uint256) {
        return payouts[passenger];
    }
    

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function () external payable {
        fund();
    }

}