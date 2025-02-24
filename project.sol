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
        if (msg.sender != owner) revert NotOwner();
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
        if(supportedTokens[symbol] != address(0)) revert AlreadySupported();
        if(tokenAddress == address(0)) revert InvalidToken();
        
        supportedTokens[symbol] = tokenAddress;
        withdrawalLimits[symbol] = initialLimit;
        emit TokenAdded(symbol, tokenAddress);
    }

    
    function setWithdrawalLimit(string memory token, uint256 newLimit) 
        external 
        onlyOwner 
    {
        if(supportedTokens[token] == address(0)) revert InvalidToken();
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
        if(msg.value == 0) revert InvalidAmount();
        emit Deposited(msg.sender, "ETH", msg.value);
    }

    function depositToken(string memory token, uint256 amount) external {
        address tokenAddress = supportedTokens[token];
        if(tokenAddress == address(0)) revert InvalidToken();
        if(amount == 0) revert InvalidAmount();

        bool success = IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        if(!success) revert TransferFailed();
        emit Deposited(msg.sender, token, amount);
    }

    
    function withdraw(uint256 amount) external noReentrant {
        if(amount == 0) revert InvalidAmount();
        if(address(this).balance < amount) revert InsufficientBalance();
        
        checkAndResetDaily();
        if(dailyWithdrawals["ETH"] + amount > withdrawalLimits["ETH"]) 
            revert LimitExceeded();

        dailyWithdrawals["ETH"] += amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if(!success) revert TransferFailed();
        
        emit Withdrawn(msg.sender, "ETH", amount);
    }

    
    function withdrawToken(string memory token, uint256 amount) external noReentrant {
        address tokenAddress = supportedTokens[token];
        if(tokenAddress == address(0)) revert InvalidToken();
        if(amount == 0) revert InvalidAmount();
        
        checkAndResetDaily();
        if(dailyWithdrawals[token] + amount > withdrawalLimits[token])
            revert LimitExceeded();

        dailyWithdrawals[token] += amount;
        bool success = IERC20(tokenAddress).transfer(msg.sender, amount);
        if(!success) revert TransferFailed();
        
        emit Withdrawn(msg.sender, token, amount);
    }

    
    function transfer(address to, uint256 amount) external noReentrant {
        if(to == address(0)) revert InvalidRecipient();
        if(amount == 0) revert InvalidAmount();
        if(address(this).balance < amount) revert InsufficientBalance();

        (bool success, ) = payable(to).call{value: amount}("");
        if(!success) revert TransferFailed();
        
        emit Transferred(msg.sender, to, "ETH", amount);
    }

   
    function transferToken(string memory token, address to, uint256 amount) 
        external 
        noReentrant 
    {
        address tokenAddress = supportedTokens[token];
        if(tokenAddress == address(0)) revert InvalidToken();
        if(to == address(0)) revert InvalidRecipient();
        if(amount == 0) revert InvalidAmount();

        bool success = IERC20(tokenAddress).transfer(to, amount);
        if(!success) revert TransferFailed();
        
        emit Transferred(msg.sender, to, token, amount);
    }

    
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    
    function getTokenBalance(string memory token) external view returns (uint256) {
        address tokenAddress = supportedTokens[token];
        if(tokenAddress == address(0)) revert InvalidToken();
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    
    function getRemainingDailyLimit(string memory token) 
        external 
        view 
        returns (uint256) 
    {
        if(supportedTokens[token] == address(0)) revert InvalidToken();
        if (block.timestamp - lastResetTimestamp >= 1 days) {
            return withdrawalLimits[token];
        }
        return withdrawalLimits[token] - dailyWithdrawals[token];
    }

    
    receive() external payable {
        emit Deposited(msg.sender, "ETH", msg.value);
    }
}
