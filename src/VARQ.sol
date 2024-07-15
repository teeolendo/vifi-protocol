// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {vToken} from "./vToken.sol";

contract VARQ is Ownable {
    vToken public vUSD;
    vToken public vTTD;
    vToken public vRT;
    uint256 public CBrate;
    address public dao;

    modifier onlyDAO() {
        require(msg.sender == dao, "Only DAO can call this");
        _;
    }

    constructor() Ownable(msg.sender) {}

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
}