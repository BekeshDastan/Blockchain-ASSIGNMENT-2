// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {
        _mint(msg.sender, 10000e18);
    }
}

contract LendingPoolTest is Test {
    LendingPool pool;
    MockERC20 token;
    address user = address(1);
    address liquidator = address(2);

    function setUp() public {
        token = new MockERC20();
        pool = new LendingPool(address(token));
        token.transfer(user, 1000e18);
        token.transfer(liquidator, 2000e18);

        vm.prank(user);
        token.approve(address(pool), type(uint256).max);
        vm.prank(liquidator);
        token.approve(address(pool), type(uint256).max);
    }

    function testDeposit() public {
        vm.prank(user);
        pool.deposit(100e18);
        (uint256 dep,) = pool.positions(user);
        assertEq(dep, 100e18);
    }

    function testBorrowWithinLTV() public {
        vm.startPrank(user);
        pool.deposit(100e18);
        pool.borrow(75e18);
        vm.stopPrank();
    }

    function test_RevertWhen_BorrowExceedsLTV() public {
        vm.startPrank(user);
        pool.deposit(100e18);

        vm.expectRevert("Exceeds LTV");
        pool.borrow(76e18);

        vm.stopPrank();
    }

    function testFullRepayment() public {
        vm.startPrank(user);
        pool.deposit(100e18);
        pool.borrow(50e18);
        pool.repay(50e18);
        (, uint256 borrowedBase) = pool.positions(user);
        assertEq(borrowedBase, 0);
        vm.stopPrank();
    }

    function testWithdrawalWithDebt() public {
        vm.startPrank(user);
        pool.deposit(100e18);
        pool.borrow(50e18);

        vm.expectRevert("Unsafe health factor");
        pool.withdraw(50e18);
        vm.stopPrank();
    }

    function testInterestAccrual() public {
        vm.startPrank(user);
        pool.deposit(100e18);
        pool.borrow(50e18);

        vm.warp(block.timestamp + 365 days);

        uint256 hf = pool.getHealthFactor(user);
        assertTrue(hf > 0);
        vm.stopPrank();
    }

    function testLiquidation() public {
        vm.prank(user);
        pool.deposit(100e18);
        vm.prank(user);
        pool.borrow(75e18);

        vm.warp(block.timestamp + 365 days * 5);

        vm.prank(liquidator);
        pool.liquidate(user);

        (uint256 dep,) = pool.positions(user);
        assertEq(dep, 0);
    }

    function testBorrowZeroCollateral() public {
        vm.prank(user);
        vm.expectRevert();
        pool.borrow(10e18);
    }

    function testPartialRepayment() public {
        vm.startPrank(user);
        pool.deposit(100e18);
        pool.borrow(50e18);
        pool.repay(25e18);
        (, uint256 borrowedBase) = pool.positions(user);
        assertTrue(borrowedBase > 0);
        vm.stopPrank();
    }

    function testWithdrawAllNoDebt() public {
        vm.startPrank(user);
        pool.deposit(100e18);
        pool.withdraw(100e18);
        (uint256 dep,) = pool.positions(user);
        assertEq(dep, 0);
        vm.stopPrank();
    }
}
