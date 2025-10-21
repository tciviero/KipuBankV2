// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol"; 

contract KipuBank is Ownable, Pausable { 
    uint private immutable bankCap; 
    uint private immutable maxWithdraw;

    AggregatorV3Interface internal priceFeed;
    
    uint8 public constant INTERNAL_DECIMALS = 6;
    
    uint private depositCount = 0;
    uint private withdrawCount = 0;
    
    mapping(address => mapping(address => uint)) private balances; 
    
    mapping(address => uint8) private tokenDecimals;

    address public constant ETH_TOKEN_ADDRESS = address(0);


    event WithdrawalSuccessful(address indexed receiver, address indexed token, uint indexed value);
    event DepositSuccessful(address indexed sender, address indexed token, uint indexed value);
    event TokenRegistered(address indexed token, uint8 decimals);
    
    
    modifier nonZeroAmount(uint amount) {
        require(amount > 0, "Cannot transfer 0.");
        _;
    }

    modifier nonZeroDeposit() {
        require(msg.value > 0, "Cannot deposit 0 ETH.");
        _;
    }

    /// @notice Checks if the new ETH deposit exceeds the bankCap (in USD value)
    modifier withinBankCap() {
        uint256 totalValueUSD = _getContractEthValueInUsd(msg.value);
        require(totalValueUSD <= bankCap, "Deposit exceeds the bank's USD limit.");
        _;
    }

    modifier hasSufficientFunds(address token, uint amount) {
        require(balances[msg.sender][token] >= amount, "Insufficient funds.");
        _;
    }

    modifier isRegistered(address token) {
        require(token == ETH_TOKEN_ADDRESS || tokenDecimals[token] > 0, "Token not registered.");
        _;
    }



    constructor(uint _bankCap, uint _maxWithdraw) 
        Ownable(msg.sender)
    { 
        bankCap = _bankCap;
        maxWithdraw = _maxWithdraw;

        priceFeed = AggregatorV3Interface(0x694AA1769357215ef4BeDFd9Bc1A8f269b950cD4);
        tokenDecimals[ETH_TOKEN_ADDRESS] = 18;
    }

    function pause() public onlyOwner { 
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    
    /// @notice Owner registers a new token's decimals for internal conversion
    function registerToken(address token, uint8 decimals) public onlyOwner {
        require(token != ETH_TOKEN_ADDRESS, "Cannot register ETH_TOKEN_ADDRESS.");
        require(decimals > 0, "Decimals must be greater than zero.");
        tokenDecimals[token] = decimals;
        emit TokenRegistered(token, decimals);
    }
    
    
    /// @notice Gets the latest ETH price in USD from the Chainlink Data Feed
    function _getLatestEthPrice() internal view returns (int256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return price;
    }

    /// @notice Calculates the total value of ETH in the contract in USD
    /// @param newDepositValue The value of the incoming deposit (in 18-decimal ETH)
    function _getContractEthValueInUsd(uint256 newDepositValue) internal view returns (uint256) {
        uint256 currentEthInternal = balances[address(this)][ETH_TOKEN_ADDRESS];
        
        uint256 currentEthExternal = _toExternalAmount(ETH_TOKEN_ADDRESS, currentEthInternal);
        
        uint256 totalEthExternal = currentEthExternal + newDepositValue;
        
        int256 price = _getLatestEthPrice();

        uint256 usdValue = (uint256(price) * totalEthExternal) / (10**26);

        return usdValue;
    }


    function _toInternalAmount(address token, uint256 externalAmount) private view returns (uint256) {
        uint8 externalDecimals = tokenDecimals[token];

        if (externalDecimals == INTERNAL_DECIMALS) {
            return externalAmount;
        }

        if (externalDecimals > INTERNAL_DECIMALS) {
            uint8 factor = externalDecimals - INTERNAL_DECIMALS;
            return externalAmount / (10**factor);
        } else {
            uint8 factor = INTERNAL_DECIMALS - externalDecimals;
            return externalAmount * (10**factor);
        }
    }

    function _toExternalAmount(address token, uint256 internalAmount) private view returns (uint256) {
        uint8 externalDecimals = tokenDecimals[token];

        if (externalDecimals == INTERNAL_DECIMALS) {
            return internalAmount;
        }

        if (externalDecimals > INTERNAL_DECIMALS) {
            uint8 factor = externalDecimals - INTERNAL_DECIMALS;
            return internalAmount * (10**factor);
        } else {
            uint8 factor = INTERNAL_DECIMALS - externalDecimals;
            return internalAmount / (10**factor);
        }
    }
    
    function _safeTransferETH(address receiver, uint256 amount) private {
        uint256 externalAmount = _toExternalAmount(ETH_TOKEN_ADDRESS, amount);
        (bool success, ) = receiver.call{value: externalAmount}("");
        require(success, "ETH transfer failed");
    }

    function _safeTransferERC20(address token, address receiver, uint256 amount) private {
        uint256 externalAmount = _toExternalAmount(token, amount);
        bool success = IERC20(token).transfer(receiver, externalAmount);
        require(success, "ERC20 transfer failed");
    }


    /// @notice Deposit native Ether (ETH_TOKEN_ADDRESS = address(0))
    function deposit()
        external
        payable
        nonZeroDeposit
        withinBankCap 
        whenNotPaused 
    {
        uint256 internalAmount = _toInternalAmount(ETH_TOKEN_ADDRESS, msg.value);
        
        balances[msg.sender][ETH_TOKEN_ADDRESS] += internalAmount; 
        balances[address(this)][ETH_TOKEN_ADDRESS] += internalAmount;
        
        depositCount += 1;
        emit DepositSuccessful(msg.sender, ETH_TOKEN_ADDRESS, internalAmount);
    }

    receive() external payable nonZeroDeposit withinBankCap whenNotPaused { 
        uint256 internalAmount = _toInternalAmount(ETH_TOKEN_ADDRESS, msg.value);
        
        balances[msg.sender][ETH_TOKEN_ADDRESS] += internalAmount;
        balances[address(this)][ETH_TOKEN_ADDRESS] += internalAmount;

        depositCount += 1;
        emit DepositSuccessful(msg.sender, ETH_TOKEN_ADDRESS, internalAmount);
    }

    fallback() external payable nonZeroDeposit withinBankCap whenNotPaused { 
        uint256 internalAmount = _toInternalAmount(ETH_TOKEN_ADDRESS, msg.value);
        
        balances[msg.sender][ETH_TOKEN_ADDRESS] += internalAmount;
        balances[address(this)][ETH_TOKEN_ADDRESS] += internalAmount;

        depositCount += 1;
        emit DepositSuccessful(msg.sender, ETH_TOKEN_ADDRESS, internalAmount);
    }

    /// @notice Deposit ERC-20 tokens
    function depositERC20(address token, uint256 amount)
        external
        nonZeroAmount(amount)
        isRegistered(token)
        whenNotPaused
    {
        uint256 internalAmount = _toInternalAmount(token, amount);


        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(success, "ERC20 transferFrom failed. Check allowance.");

        balances[msg.sender][token] += internalAmount;
        
        depositCount += 1;
        emit DepositSuccessful(msg.sender, token, internalAmount);
    }


    /// @notice Withdraw ETH or ERC-20 tokens
    function withdraw(address token, uint256 amount)
        external
        nonZeroAmount(amount)
        hasSufficientFunds(token, amount)
        isRegistered(token)
        whenNotPaused
    {
        // Amount argument is expected to be in the INTERNAL_DECIMALS (6) standard
        
        // Only apply the Max Withdrawal limit to native ETH
        if (token == ETH_TOKEN_ADDRESS) {
            require(amount <= maxWithdraw, "ETH withdrawal amount exceeds limit (internal 6-decimals).");
        }
        
        balances[msg.sender][token] -= amount;

        if (token == ETH_TOKEN_ADDRESS) {
            _safeTransferETH(msg.sender, amount);
            balances[address(this)][ETH_TOKEN_ADDRESS] -= amount;
        } else {
            _safeTransferERC20(token, msg.sender, amount);
        }

        withdrawCount += 1;
        emit WithdrawalSuccessful(msg.sender, token, amount);
    }
    
    function getBalance(address token) public view returns (uint) {
        return balances[msg.sender][token];
    }
    
    function getBalances(address token, address[] calldata users)
        external
        view
        onlyOwner
        returns (uint256[] memory)
    {
        uint256[] memory balancesArray = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            balancesArray[i] = balances[users[i]][token];
        }
        return balancesArray;
    }
    
    /// @notice Helper function for external display: returns the current total ETH value in USD
    function getTotalEthValueInUsd() public view returns (uint256) {
        return _getContractEthValueInUsd(0);
    }
}