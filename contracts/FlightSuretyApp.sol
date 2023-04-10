pragma solidity >=0.4.25 <0.6.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA CONSTANTS                                     */
    /********************************************************************************************/

    uint256 private constant MIN_AIRLINES_COUNT = 4;
    uint256 public constant MIN_FUNDS = 10 ether;
    uint256 private constant MAX_PREMIUM = 1 ether;
    uint256 private constant PAYOUT_PERCENT = 150;

    // Airline satus codes
    uint8 private constant UNREGISTERED = 0; // empty value
    uint8 private constant PENDING = 10;
    uint8 private constant REGISTERED = 20;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract
    address private _dataContractAddress;

    bool private contractOperational = true;

    // Data Contract
    IFlightSuretyData flightSuretyData;

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
         // Modify to call data contract's status
        require(contractOperational, "Contract is currently not operational");  
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
    * @dev Modifier that requires the airline to be funded to participate
    */
    modifier requireAirlineIsFunded()
    {
        require(flightSuretyData.getAirlineFunds(msg.sender) >= MIN_FUNDS, "Airline is not fundede");
        _;
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /* Event fired when a new airline is registered */
    event RegisteredAirline(address airline);

    /* Event fired when a passenger buys a policy */
    event BoughtPolicy(address airline, string flight, uint256 timestamp, address passenger, uint256 premium);


    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataContractAddress
                                )
                                public
    {
        contractOwner = msg.sender;
        // Create data contract
        flightSuretyData = IFlightSuretyData(dataContractAddress);
        _dataContractAddress = dataContractAddress;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return contractOperational;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                            (
                                address airlineAddress,
                                string memory airlineName
                            )
                            public
                            requireIsOperational
                            returns(bool success, uint256 votes)
    {
        // new airline must be unknown
        require(flightSuretyData.getAirlineStatus(airlineAddress) == UNREGISTERED, "Airline is already registered or pending");
        // registering airline must be funded
        require(flightSuretyData.getAirlineFunds(msg.sender) >=  MIN_FUNDS, "Airline should not be able to register another airline if it hasn't provided funding");
        // First 4 airlines must be submitted by another airline
        // After 4, must be approved by a majority of airlines
        if (flightSuretyData.getRegisteredAirlinesCount() < MIN_AIRLINES_COUNT) {
            // ensure submitted by another airline
            require(flightSuretyData.getAirlineStatus(msg.sender) == REGISTERED, "Airline must be submitted by another airline until 5 participants reached");
            // register airline in data contract
            flightSuretyData.registerAirline(airlineAddress, airlineName, REGISTERED);
            success = true;
            votes = 0;
            emit RegisteredAirline(airlineAddress);
        } else {
            // airline is pending consensus
            flightSuretyData.registerAirline(airlineAddress, airlineName, PENDING);
            success = true;
            votes = 0;
        }
        return (success, votes);
    }

    /**
    * Add pay funds to an airline account
    *
    */   
    function fundAirline
                            (
                                address airlineAddress
                            )
                            external
                            payable
                            requireIsOperational
                            returns (uint256)
    {
        require(flightSuretyData.getAirlineStatus(airlineAddress) != UNREGISTERED, "Airline must be registered prior to funding");
        // Cast address to payable address
        // address payable flightSuretyDataAddressPayable = _make_payable(address(flightSuretyData));
        // address payable dataContractAddress = address(uint160(address(flightSuretyData)));
        // flightSuretyDataAddressPayable.transfer({value: msg.value, from: airlineAddress});
        address(uint160(address(flightSuretyData))).transfer(msg.value);
        flightSuretyData.fundAirline(airlineAddress, msg.value);
        return flightSuretyData.getAirlineFunds(airlineAddress);
    }

    /**
    * Add vote for airline
    *
    */   
    function voteForAirline
                            (
                                address airlineAddress
                            )
                            external
                            requireIsOperational
                            returns (uint256)
    {
        // voters must be regisitered
        require(flightSuretyData.isAirlineRegistered(msg.sender), "Airline must be registered to vote");
        // airline being voted on must exist
        require(flightSuretyData.isAirline(airlineAddress), "Airline must exist to be voted on");
        flightSuretyData.voteForAirline(msg.sender, airlineAddress);

        uint256 airlineVotes = flightSuretyData.getAirlineVoteCount(airlineAddress);

        if (airlineVotes >= flightSuretyData.getRegisteredAirlinesCount().div(2)) {
            flightSuretyData.approveAirline(airlineAddress);
            emit RegisteredAirline(airlineAddress);
        }
        return airlineVotes;
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */ 
    
    function registerFlight
                                (
                                    uint256 timestamp,
                                    string calldata flight
                                )
                                external
                                requireIsOperational
                                requireAirlineIsFunded
    {
        flightSuretyData.registerFlight(timestamp, msg.sender, flight);
        // emit FlightRegistered(msg.sender, flight, from, to, timestamp);
    }

   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
    {
        // TODO: If status code is STATUS_CODE_LATE_AIRLINE
        // Find passengers with inurance and pay them
        flightSuretyData.setFlightStatus(airline, flight, timestamp, statusCode);

        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            flightSuretyData.creditInsurees(airline, flight, timestamp);
        }
    }

    function buyInsurance(address airline, string calldata flight, uint256 timestamp) external payable requireIsOperational
    {
        // insurance policy premium must be > 0 and <= 1 eth
        require((msg.value > 0) && (msg.value <= MAX_PREMIUM), "insurance policy premium must be > 0 and <= 1 eth");
        // airline must be registered and funded
        require(flightSuretyData.isAirlineRegistered(airline), "Airline must be registered");
        // airline must be funded
        require(flightSuretyData.getAirlineFunds(airline) >= MIN_FUNDS, "Airline must be funded");
        // flight must be registered
        require(flightSuretyData.isFlight(timestamp, airline, flight), "Flight must be registered");
        // policy must not already exist
        require(!flightSuretyData.isInsured(msg.sender, airline, flight, timestamp), "Policy must not already exist");
        // transfer the money from the passenger to contact
        address(uint160(address(flightSuretyData))).transfer(msg.value);
        // buy policy
        flightSuretyData.buy(msg.sender, airline, flight, timestamp, msg.value, PAYOUT_PERCENT);
        // emit bought policy event
        emit BoughtPolicy(airline, flight, timestamp, msg.sender, msg.value);
    }

    // function withdrawPayout() external payable
    // {
    //    flightSuretyData.pay(msg.sender);
    // }

    function getOracleKey(
                            uint8 index,
                            address airline,
                            string calldata flight,
                            uint256 timestamp                            
                        )
                        external
                        view
                        returns(bytes32, bytes32, bool)
                        {
                            uint8 testIndex = 0;
                            bytes32 key1 = keccak256(abi.encodePacked(testIndex, airline, flight, timestamp));
                            bytes32 key2 = keccak256(abi.encodePacked(index, airline, flight, timestamp));
                            return (key1, key2, oracleResponses[key1].isOpen);
                        }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string calldata flight,
                            uint256 timestamp                            
                        )
                        external
                        returns(bool, bytes32)
    {
        // uint8 index = getRandomIndex(msg.sender);
        uint8 index = 0;

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        // TypeError: Struct containing a (nested) mapping cannot be constructed.
        // ResponseInfo storage newResponseInfo = oracleResponses[key];
        // newResponseInfo.requester = msg.sender;
        // newResponseInfo.isOpen = true;
        
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });
                                        
        emit OracleRequest(index, airline, flight, timestamp);
        return (oracleResponses[key].isOpen, key);
    }



// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)


    function oracleResponseIsopen
                        (
                            uint8 index,
                            address airline,
                            string calldata flight,
                            uint256 timestamp
                        )
                            external
                            view
                            returns(bool)
                        {
                            bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
                            return oracleResponses[key].isOpen;
                        }

    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string calldata flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

    function () external payable {
    }

}

// Data contract interface
interface IFlightSuretyData {
    function isOperational() external view returns(bool);
    function isAirline(address airlineAddress) external view returns(bool);
    function registerAirline(address airlineAddress, string calldata airlineName, uint8 airlineStatus) external;
    function getRegisteredAirlinesCount() external view returns (uint256);
    function getAirlineVoteCount(address airlineAddress) external view returns (uint256);
    function getAirlineStatus(address airlineAddress) external view returns (uint8);
    function getAirlineFunds(address airlineAddress) external view returns (uint256);
    function approveAirline(address airlineAddress) external;
    function voteForAirline(address votingAirlineAddress, address airlineAddress) external;
    function fundAirline(address airlineAddress, uint256 funds) external returns (uint256);
    function isAirlineRegistered(address airlineAddress) external view returns(bool);
    function registerFlight(uint256 timestamp, address airline, string calldata flight) external;
    function isFlight(uint256 timestamp, address airline, string calldata flight) external view returns(bool);
    function isInsured(address passenger, address airline, string calldata flight, uint256 timestamp) external view returns(bool);
    function buy(address passenger, address airline, string calldata flight, uint256 timestamp, uint256 premium, uint256 multiplier) external payable returns(bytes32);
    function creditInsurees(address airline, string calldata flight, uint256 timestamp) external;
    function setFlightStatus(address airline, string calldata flight, uint256 timestamp, uint8 statusCode) external;
}