// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract vToken is ERC20, Ownable {
    mapping(address => bool) private _controllers;

    modifier onlyController() {
        require(_controllers[msg.sender], "Not a controller");
        _;
    }

    constructor(string memory name, string memory symbol, address owner) ERC20(name, symbol) Ownable(msg.sender) {}

    function setController(address controller, bool isController) public onlyOwner {
        _controllers[controller] = isController;
    }

    function mint(address to, uint256 amount) external onlyController {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyController {
        _burn(from, amount);
    }
}