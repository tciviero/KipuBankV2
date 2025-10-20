// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

contract KipuBank {
    uint private immutable bankCap;
    uint private immutable maxWithdraw;
    uint private depositCount = 0;
    uint private withdrawCount = 0;
    uint private totalBalance = 0;
    mapping(address => uint) private balances;
    address public owner;

    event WithdrawalSuccessful(address indexed receiver, uint indexed value);
    event DepositSuccessful(address indexed sender, uint indexed value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can execute this function.");
        _;
    }

    modifier nonZeroDeposit() {
        require(msg.value > 0, "Cannot deposit 0 ETH.");
        _;
    }

    modifier withinBankCap() {
        require(totalBalance + msg.value < bankCap, "Deposit exceeds the bank's ETH limit.");
        _;
    }

    modifier hasSufficientFunds(uint amount) {
        require(balances[msg.sender] >= amount, "Insufficient funds.");
        _;
    }

    modifier withinWithdrawLimit(uint amount) {
        require(amount <= maxWithdraw, "Withdrawal amount exceeds limit.");
        _;
    }

    modifier transferSucceeded(bool success) {
        require(success, "Transfer failed");
        _;
    }

    constructor(uint _bankCap, uint _maxWithdraw) {
        bankCap = _bankCap;
        maxWithdraw = _maxWithdraw;
        owner = msg.sender;
    }


    function _safeTransfer(address receiver, uint256 amount) private {
        (bool success, ) = receiver.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /// @notice Deposit ETH from your account
    function deposit()
        external
        payable
        nonZeroDeposit
        withinBankCap
    {
        balances[msg.sender] += msg.value; 
        depositCount += 1;
        totalBalance += msg.value;
        emit DepositSuccessful(msg.sender, msg.value);
    }

    receive() external payable nonZeroDeposit withinBankCap {
        balances[msg.sender] += msg.value;
        depositCount += 1;
        totalBalance += msg.value;
        emit DepositSuccessful(msg.sender, msg.value);
    }

    fallback() external payable nonZeroDeposit withinBankCap {
        balances[msg.sender] += msg.value;
        depositCount += 1;
        totalBalance += msg.value;
        emit DepositSuccessful(msg.sender, msg.value);
    }

    /// @notice Withdraw ETH from your account
    /// @param amount The amount of ETH to withdraw in wei
    function withdraw(uint256 amount)
        external
        hasSufficientFunds(amount)
        withinWithdrawLimit(amount)
    {
        balances[msg.sender] -= amount;
        withdrawCount += 1;
        totalBalance -= amount;

        _safeTransfer(msg.sender, amount);
        emit WithdrawalSuccessful(msg.sender, amount);
    }

    function getBalance() public view returns (uint) {
        return balances[msg.sender];
    }

    function getBalances(address[] calldata users)
        external
        view
        onlyOwner
        returns (uint256[] memory)
    {
        uint256[] memory balancesArray = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            balancesArray[i] = balances[users[i]];
        }
        return balancesArray;
    }
}
