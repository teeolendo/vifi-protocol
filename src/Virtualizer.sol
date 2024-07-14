// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {vToken} from "./vToken.sol";

contract Virtualizer {
    IERC20 public mUSDC;
    vToken public vUSD;

    constructor(address _mUSDC, address _vUSD) {
        mUSDC = IERC20(_mUSDC);
        vUSD = vToken(_vUSD);
    }

    function wrap(uint256 amount) public {
        mUSDC.transferFrom(msg.sender, address(this), amount);
        vUSD.mint(msg.sender, amount);
    }

    function unwrap(uint256 amount) public {
        vUSD.burn(msg.sender, amount);
        mUSDC.transfer(msg.sender, amount);
    }
}