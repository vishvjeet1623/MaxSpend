// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


interface IERC20 {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MaxSpend {
    address public owner;
    bool private locked;

    
    mapping(string => address) public supportedTokens;
    
   
    mapping(string => uint256) public withdrawalLimits;
    
   
    mapping(string => uint256) public dailyWithdrawals;
    
   
    uint256 public lastResetTimestamp;
    
    
    event Deposited(address indexed user, string token, uint256 amount);
    event Withdrawn(address indexed user, string token, uint256 amount);
    event Transferred(address indexed from, address indexed to, string token, uint256 amount);
    event LimitsUpdated(string token, uint256 newLimit);
    event TokenAdded(string symbol, address tokenAddress);

    
    error NotOwner();
    error AlreadySupported();
    error InvalidToken();
    error InvalidAmount();
    error InvalidRecipient();
    error InsufficientBalance();
    error LimitExceeded();
    error TransferFailed();

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    constructor() {
        owner = msg.sender;
       
        supportedTokens["ETH"] = address(0); 
        withdrawalLimits["ETH"] = 5 ether;   
        
        
        lastResetTimestamp = block.timestamp - (block.timestamp % 1 days);
    }

    
    function addToken(string memory symbol, address tokenAddress, uint256 initialLimit) 
        external 
        onlyOwner 
    {
        require(supportedTokens[symbol] == address(0), "Token already supported");
        require(tokenAddress != address(0), "Invalid token address");
        
        supportedTokens[symbol] = tokenAddress;
        withdrawalLimits[symbol] = initialLimit;
        emit TokenAdded(symbol, tokenAddress);
    }

    
    function setWithdrawalLimit(string memory token, uint256 newLimit) 
        external 
        onlyOwner 
    {
        require(supportedTokens[token] != address(0), "Token not supported");
        withdrawalLimits[token] = newLimit;
        emit LimitsUpdated(token, newLimit);
    }

    
    function checkAndResetDaily() internal {
        uint256 currentDay = block.timestamp - (block.timestamp % 1 days);
        if (currentDay > lastResetTimestamp) {
            lastResetTimestamp = currentDay;
            dailyWithdrawals["ETH"] = 0;
            dailyWithdrawals["USDT"] = 0;
            dailyWithdrawals["USDC"] = 0;
            dailyWithdrawals["DAI"] = 0;
        }
    }

   
    function deposit() external payable {
        require(msg.value > 0, "Must send ETH");
        emit Deposited(msg.sender, "ETH", msg.value);
    }

    function depositToken(string memory token, uint256 amount) external {
        address tokenAddress = supportedTokens[token];
        require(tokenAddress != address(0), "Token not supported");
        require(amount > 0, "Amount must be greater than 0");

        bool success = IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");
        emit Deposited(msg.sender, token, amount);
    }

    
    function withdraw(uint256 amount) external noReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient balance");
        
        checkAndResetDaily();
        require(dailyWithdrawals["ETH"] + amount <= withdrawalLimits["ETH"], 
                "Daily withdrawal limit exceeded");

        dailyWithdrawals["ETH"] += amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
        
        emit Withdrawn(msg.sender, "ETH", amount);
    }

    
    function withdrawToken(string memory token, uint256 amount) external noReentrant {
        address tokenAddress = supportedTokens[token];
        require(tokenAddress != address(0), "Token not supported");
        require(amount > 0, "Amount must be greater than 0");
        
        checkAndResetDaily();
        require(dailyWithdrawals[token] + amount <= withdrawalLimits[token],
                "Daily withdrawal limit exceeded");

        dailyWithdrawals[token] += amount;
        bool success = IERC20(tokenAddress).transfer(msg.sender, amount);
        require(success, "Token transfer failed");
        
        emit Withdrawn(msg.sender, token, amount);
    }

    
    function transfer(address to, uint256 amount) external noReentrant {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient balance");

        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "ETH transfer failed");
        
        emit Transferred(msg.sender, to, "ETH", amount);
    }

   
    function transferToken(string memory token, address to, uint256 amount) 
        external 
        noReentrant 
    {
        address tokenAddress = supportedTokens[token];
        require(tokenAddress != address(0), "Token not supported");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");

        bool success = IERC20(tokenAddress).transfer(to, amount);
        require(success, "Token transfer failed");
        
        emit Transferred(msg.sender, to, token, amount);
    }

    
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    
    function getTokenBalance(string memory token) external view returns (uint256) {
        address tokenAddress = supportedTokens[token];
        require(tokenAddress != address(0), "Token not supported");
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    
    function getRemainingDailyLimit(string memory token) 
        external 
        view 
        returns (uint256) 
    {
        require(supportedTokens[token] != address(0), "Token not supported");
        if (block.timestamp - lastResetTimestamp >= 1 days) {
            return withdrawalLimits[token];
        }
        return withdrawalLimits[token] - dailyWithdrawals[token];
    }

    
    receive() external payable {
        emit Deposited(msg.sender, "ETH", msg.value);
    }
}
