pragma solidity >=0.4.25 <0.9.0;

import "../node_modules/openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

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

    // App Contracts
    mapping(address => bool) private authorizedContracts;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address firstAirlineAddress,
                                    string memory firstAirlineName
                                )
                                payable
                                public 
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
    function getAirlineVoteCount(address airlineAddress) public view returns(uint256) {
        return airlineVotes[airlineAddress].length;
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
        _registerAirline(airlineAddress, airlineName, airlineStatus);
    }

    // Internal function to register airline
    function _registerAirline
                            (
                                address airlineAddress,
                                string memory airlineName,
                                uint8 airlineStatus
                            )
                            internal
                            requireIsOperational
    {
        airlines[airlineAddress] = Airline({
            name: airlineName,
            status: airlineStatus,
            funds: 0
        });
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
                                address airlineAddress
                            )
                            external
                            payable
                            requireIsOperational
                            requireIsAuthorized
                            returns(uint256)
    {
        uint256 currentFunds = airlines[airlineAddress].funds;
        currentFunds.add(msg.value);
        airlines[airlineAddress].funds = currentFunds;
        return currentFunds;
    }

    function voteForAirline(address airlineAddress) external requireIsOperational requireIsAuthorized
    {    
        // make sure that each airline only votes once
        for (uint256 i = 0; i < airlineVotes[airlineAddress].length; i++) {
            require(airlineVotes[airlineAddress][i] != msg.sender, "Airline has already voted for this applicant");
        }
        airlineVotes[airlineAddress].push(msg.sender);
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
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

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    fallback() external payable { }

}

