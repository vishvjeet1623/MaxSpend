// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SharedWallet {
    address public owner;
    mapping(address => bool) public isAllowedToSpend;
    mapping(address => uint256) public spendingLimit;
    mapping(address => uint256) public dailySpent;
    mapping(address => uint256) public lastSpendTimestamp;

    event Deposit(address indexed sender, uint256 amount);
    event Withdrawal(address indexed recipient, uint256 amount);
    event SpenderAdded(address indexed spender, uint256 limit);
    event SpenderRemoved(address indexed spender);

    constructor() {
        owner = msg.sender;
        isAllowedToSpend[msg.sender] = true;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier canSpend(uint256 _amount) {
        require(isAllowedToSpend[msg.sender], "Not authorized to spend");
        if (msg.sender != owner) {
            require(_amount <= spendingLimit[msg.sender], "Amount exceeds spending limit");
            
            // Reset daily spent if 24 hours have passed
            if (block.timestamp >= lastSpendTimestamp[msg.sender] + 1 days) {
                dailySpent[msg.sender] = 0;
            }
            
            require(dailySpent[msg.sender] + _amount <= spendingLimit[msg.sender], 
                    "Daily spending limit exceeded");
        }
        _;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function addSpender(address _spender, uint256 _limit) external onlyOwner {
        isAllowedToSpend[_spender] = true;
        spendingLimit[_spender] = _limit;
        emit SpenderAdded(_spender, _limit);
    }

    function removeSpender(address _spender) external onlyOwner {
        require(_spender != owner, "Cannot remove owner");
        isAllowedToSpend[_spender] = false;
        spendingLimit[_spender] = 0;
        emit SpenderRemoved(_spender);
    }

    function withdraw(uint256 _amount) external canSpend(_amount) {
        require(address(this).balance >= _amount, "Insufficient balance");
        
        if (msg.sender != owner) {
            dailySpent[msg.sender] += _amount;
            lastSpendTimestamp[msg.sender] = block.timestamp;
        }

        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Transfer failed");
        
        emit Withdrawal(msg.sender, _amount);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
