// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken public token;
    
    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    
    uint256 constant INITIAL_SUPPLY = 10_000 * 10**18;

    function setUp() public {
        token = new MyToken(INITIAL_SUPPLY);
        
        excludeSender(owner); 
        
        targetContract(address(token));
    }

    
    function test_Mint() public {
        token.mint(user1, 1000);
        assertEq(token.balanceOf(user1), 1000);
    }

    function test_MintRevertsIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user1, 1000);
    }

    function test_Transfer() public {
        token.transfer(user1, 500);
        assertEq(token.balanceOf(user1), 500);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - 500);
    }

    function test_TransferRevertsIfInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, 100);
    }

    function test_TransferRevertsIfToZeroAddress() public {
        vm.expectRevert();
        token.transfer(address(0), 100);
    }

    function test_Approve() public {
        token.approve(user1, 1000);
        assertEq(token.allowance(owner, user1), 1000);
    }

    function test_ApproveRevertsIfToZeroAddress() public {
        vm.expectRevert();
        token.approve(address(0), 100);
    }

    function test_TransferFrom() public {
        token.approve(user1, 1000);
        
        vm.prank(user1);
        token.transferFrom(owner, user2, 500);
        
        assertEq(token.balanceOf(user2), 500);
        assertEq(token.allowance(owner, user1), 500);
    }

    function test_TransferFromRevertsIfInsufficientAllowance() public {
        token.approve(user1, 500);
        
        vm.prank(user1);
        vm.expectRevert();
        token.transferFrom(owner, user2, 600);
    }

    function test_TransferFromRevertsIfInsufficientBalance() public {
        token.mint(user1, 100);
        
        vm.prank(user1);
        token.approve(user2, 500); 
        
        vm.prank(user2);
        vm.expectRevert();
        token.transferFrom(user1, owner, 200);
    }

    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 0, token.balanceOf(owner));
        
        uint256 preBalanceOwner = token.balanceOf(owner);
        uint256 preBalanceUser1 = token.balanceOf(user1);

        token.transfer(user1, amount);

        assertEq(token.balanceOf(owner), preBalanceOwner - amount);
        assertEq(token.balanceOf(user1), preBalanceUser1 + amount);
    }

    function invariant_TotalSupplyRemainsConstant() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function invariant_BalancesNeverExceedTotalSupply() public view {
        assertLe(token.balanceOf(user1), token.totalSupply());
        assertLe(token.balanceOf(user2), token.totalSupply());
        assertLe(token.balanceOf(owner), token.totalSupply());
    }
}