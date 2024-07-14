// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {FunctionsClient} from "@chainlink/contracts/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {vToken} from "./vToken.sol";

contract VARQ is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;
    vToken public vUSD;
    vToken public vTTD;
    vToken public vRT;
    uint256 public CBrate;
    address public dao;

    // State variables to store the last request ID, response, and error
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    address public router;
    uint32 gasLimit = 300000;
    bytes32 donID;
    string public character;

    error UnexpectedRequestID(bytes32 requestId);
    // Event to log responses
    event Response(
        bytes32 indexed requestId,
        string character,
        bytes response,
        bytes err
    );
    

    modifier onlyDAO() {
        require(msg.sender == dao, "Only DAO can call this");
        _;
    }

    constructor(
        address chainlinkrouter,
        bytes32 _donID
    ) FunctionsClient(router) ConfirmedOwner(msg.sender) {
        router = chainlinkrouter;
        donID = _donID;
    }

    function initialize(
        address _vUSD,
        address _vTTD,
        address _vRT
    ) external onlyOwner {
        vUSD = vToken(_vUSD);
        vTTD = vToken(_vTTD);
        vRT = vToken(_vRT);
    }

    function setDAO(address _dao) external onlyOwner {
        require(_dao != address(0), "Invalid DAO address");
        dao = _dao;
    }

    function setCBrate(uint256 _CBrate) external onlyDAO {
        CBrate = _CBrate;
    }

    function convertVUSDToTokens(
        uint256 vUSDAmount,
        address destination
    ) public {
        vUSD.burn(msg.sender, vUSDAmount);
        vRT.mint(destination, vUSDAmount);
        vTTD.mint(destination, (vUSDAmount * CBrate) / 100); // Adjusted for 2 decimal places
    }

    function convertTokensToVUSD(
        uint256 vRTAmount,
        address destination
    ) public {
        uint256 burnCBrate = getBurnCBrate();
        uint256 vTTDAmount = (vRTAmount * burnCBrate) / 100; // Adjusted for 2 decimal places

        require(vTTD.balanceOf(msg.sender) > vTTDAmount, "Not Enough, vTTD");

        //require(( vTTDAmount * 100 ) / burnCBrate == vRTAmount, "Amounts mismatch");

        vTTD.burn(msg.sender, vTTDAmount);
        vRT.burn(msg.sender, vRTAmount);
        vUSD.mint(destination, vRTAmount);
    }

    function getBurnCBrate() public view returns (uint256) {
        return (vTTD.totalSupply() * 100) / vRT.totalSupply(); // Adjusted for 2 decimal places
    }

    string source =
        "const currency = args[0];"
        "const apiResponse = await Functions.makeHttpRequest({"
        "url: 'https://sheetdb.io/api/v1/qts5sjiimozoi/search?currency=${currency}'})"
        "if (apiResponse.error) {"
        "throw Error('Request failed')"
        "};"
        "const { data } = apiResponse;"
        "return Functions.encodeString(data[0].value)";

    /**
     * @notice Sends an HTTP request for character information
     * @param subscriptionId The ID for the Chainlink subscription
     * @param args The arguments to pass to the HTTP request
     * @return requestId The ID of the request
     */
    function sendRequest(
        uint64 subscriptionId,
        string[] calldata args
    ) external onlyOwner returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        return s_lastRequestId;
    }

     /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     * @param err Any errors from the Functions request
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId); // Check if request IDs match
        }
        // Update the contract's state variables with the response and any errors
        s_lastResponse = response;
        character = string(response);
        s_lastError = err;

        // Emit an event to log the response
        emit Response(requestId, character, s_lastResponse, s_lastError);
    }
}