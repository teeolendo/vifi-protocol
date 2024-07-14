// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {vToken} from "./vToken.sol";
import {VARQ} from "./VARQ.sol";
import {Virtualizer} from "./Virtualizer.sol";

contract ViFiDAO is Ownable {
    vToken public vUSD;
    vToken public vTTD;
    vToken public vRT;

    VARQ public varq;
    Virtualizer public virtualizer;

    constructor(address _mUSDCAddress, address chainlinkrouter, bytes32 _donID) Ownable(msg.sender) {
        vUSD = new vToken("Virtual USD", "vUSD", msg.sender);
        vTTD = new vToken("Virtual Trinidad Tobago Dollars", "vTTD", msg.sender);
        vRT = new vToken("Virtual Reserve Token", "vRT", msg.sender);

        varq = new VARQ(chainlinkrouter, _donID);
        virtualizer = new Virtualizer(_mUSDCAddress, address(vUSD));

        vUSD.setController(address(virtualizer), true);
        vUSD.setController(address(varq), true);
        vTTD.setController(address(varq), true);
        vRT.setController(address(varq), true);

        // Post-initialization to set up the DAO address correctly
        varq.initialize(address(vUSD), address(vTTD), address(vRT));
        varq.setDAO(address(this));
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
}
