// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts@4.9.3/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts@4.9.3/access/Ownable.sol";

contract DepositAndClaimContract is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint256 public claimAmount;
    mapping(address => uint256) public claimCount;

    event Deposited(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event ClaimCountReset(address indexed user);

    constructor(IERC20 _token, uint256 _claimAmount) {
        token = _token;
        claimAmount = _claimAmount;
    }

    function deposit(uint256 amount) public {
        require(amount > 0, "Deposit amount must be greater than zero");
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function claim() public {
        require(claimCount[msg.sender] < 10, "Claim limit reached");
        require(token.balanceOf(address(this)) >= claimAmount, "Insufficient balance in contract");
        claimCount[msg.sender] += 1;
        token.safeTransfer(msg.sender, claimAmount);
        emit Claimed(msg.sender, claimAmount);
    }

    function resetClaimCount(address user) public onlyOwner {
        claimCount[user] = 0;
        emit ClaimCountReset(user);
    }

    // Owner can update claim amount
    function updateClaimAmount(uint256 _newClaimAmount) public onlyOwner {
        claimAmount = _newClaimAmount;
    }
}
