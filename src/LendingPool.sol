// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LendingPool is ReentrancyGuard {
    IERC20 public immutable token;
    
    uint256 public constant LTV = 75; 
    uint256 public constant LIQUIDATION_THRESHOLD = 80; 
    uint256 public constant BASE_RATE = 2; 
    
    struct UserPosition {
        uint256 deposited;
        uint256 borrowedBase; 
    }

    mapping(address => UserPosition) public positions;
    uint256 public totalBorrows;
    uint256 public borrowIndex = 1e18;
    uint256 public lastUpdateTimestamp;

    event Deposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Liquidated(address indexed user, uint256 amount, uint256 collateralSeized);

    constructor(address _token) {
        token = IERC20(_token);
        lastUpdateTimestamp = block.timestamp;
    }

    function _updateInterest() internal {
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;
        if (timeElapsed > 0 && totalBorrows > 0) {
            uint256 interest = (borrowIndex * BASE_RATE * timeElapsed) / (365 days * 100);
            borrowIndex += interest;
        }
        lastUpdateTimestamp = block.timestamp;
    }

    function deposit(uint256 amount) external nonReentrant {
        _updateInterest();
        token.transferFrom(msg.sender, address(this), amount);
        positions[msg.sender].deposited += amount;
        emit Deposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonReentrant {
        _updateInterest();
        uint256 currentDebt = (positions[msg.sender].borrowedBase * borrowIndex) / 1e18;
        uint256 maxBorrow = (positions[msg.sender].deposited * LTV) / 100;
        
        require(currentDebt + amount <= maxBorrow, "Exceeds LTV");
        
        positions[msg.sender].borrowedBase += (amount * 1e18) / borrowIndex;
        totalBorrows += amount;
        token.transfer(msg.sender, amount);
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external nonReentrant {
        _updateInterest();
        uint256 currentDebt = (positions[msg.sender].borrowedBase * borrowIndex) / 1e18;
        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;

        token.transferFrom(msg.sender, address(this), repayAmount);
        positions[msg.sender].borrowedBase -= (repayAmount * 1e18) / borrowIndex;
        totalBorrows -= repayAmount;
        emit Repaid(msg.sender, repayAmount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        _updateInterest();
        require(positions[msg.sender].deposited >= amount, "Insufficient balance");
        
        positions[msg.sender].deposited -= amount;
        require(getHealthFactor(msg.sender) >= 1e18, "Unsafe health factor");
        
        token.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function liquidate(address user) external nonReentrant {
        _updateInterest();
        require(getHealthFactor(user) < 1e18, "Position healthy");

        uint256 debt = (positions[user].borrowedBase * borrowIndex) / 1e18;
        uint256 collateral = positions[user].deposited;

        uint256 amountToRepay = debt;
        
        token.transferFrom(msg.sender, address(this), amountToRepay);
        
        positions[user].borrowedBase = 0;
        positions[user].deposited = 0;
        
        if (amountToRepay > totalBorrows) {
            totalBorrows = 0;
        } else {
            totalBorrows -= amountToRepay;
        }
        
        token.transfer(msg.sender, collateral);
        emit Liquidated(user, amountToRepay, collateral);
}

    function getHealthFactor(address user) public view returns (uint256) {
        uint256 debt = (positions[user].borrowedBase * borrowIndex) / 1e18;
        if (debt == 0) return 100e18; 
        return (positions[user].deposited * LIQUIDATION_THRESHOLD * 1e18) / (debt * 100);
    }
}