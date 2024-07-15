// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {vToken} from "./vToken.sol";
import {VARQ} from "./VARQ.sol";
import {Virtualizer} from "./Virtualizer.sol";
import {FunctionsClient} from "@chainlink/contracts/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract ViFiDAO is FunctionsClient, Ownable {
    using FunctionsRequest for FunctionsRequest.Request;
    vToken public vUSD;
    vToken public vTTD;
    vToken public vRT;

    VARQ public varq;
    Virtualizer public virtualizer;

    //Chainlink Variables
    address chainlinkrouter;
    bytes32 donID;
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    address public router;
    uint32 gasLimit = 300000;
    string public character;

    error UnexpectedRequestID(bytes32 requestId);
    event Response(
        bytes32 indexed requestId,
        string character,
        bytes response,
        bytes err
    );
    

    constructor(address _mUSDCAddress, address _chainlinkrouter, bytes32 _donID) FunctionsClient(_chainlinkrouter) Ownable(msg.sender) {
        vUSD = new vToken("Virtual USD", "vUSD", msg.sender);
        vTTD = new vToken("Virtual Trinidad Tobago Dollars", "vTTD", msg.sender);
        vRT = new vToken("Virtual Reserve Token", "vRT", msg.sender);

        varq = new VARQ();
        virtualizer = new Virtualizer(_mUSDCAddress, address(vUSD));

        vUSD.setController(address(virtualizer), true);
        vUSD.setController(address(varq), true);
        vTTD.setController(address(varq), true);
        vRT.setController(address(varq), true);

        // Post-initialization to set up the DAO address correctly
        varq.initialize(address(vUSD), address(vTTD), address(vRT));
        varq.setDAO(address(this));

        router = _chainlinkrouter;
        donID = _donID;
    }

    function setCBrate(uint256 _CBrate) public onlyOwner {
        varq.setCBrate(_CBrate);
    }

    function setVarq(address _varq) public onlyOwner {
        require(_varq != address(0), "Invalid VARQ address");
        varq = VARQ(_varq);
        // Ensure the new varq is properly initialized and set as a controller
        varq.initialize(address(vUSD), address(vTTD), address(vRT));
        varq.setDAO(address(this));
        vUSD.setController(address(varq), true);
        vTTD.setController(address(varq), true);
        vRT.setController(address(varq), true);
    }

    function setVirtualizer(address _virtualizer) public onlyOwner {
        require(_virtualizer != address(0), "Invalid Virtualizer address");
        virtualizer = Virtualizer(_virtualizer);
        // Ensure the new virtualizer is set as a controller
        vUSD.setController(address(virtualizer), true);
    }

    /**
     * @dev Chainlink Functions Logic
     */

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
