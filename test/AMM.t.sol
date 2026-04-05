// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "../src/MockToken.sol";

contract AMMTest is Test {
    AMM amm;
    MockToken token0;
    MockToken token1;
    address user = address(1);
    address user2 = address(2);

    function setUp() public {
        token0 = new MockToken("Token 0", "TK0");
        token1 = new MockToken("Token 1", "TK1");
        amm = new AMM(address(token0), address(token1));

        token0.transfer(user, 100000e18);
        token1.transfer(user, 100000e18);
        token0.transfer(user2, 100000e18);
        token1.transfer(user2, 100000e18);

        vm.startPrank(user);
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    function test_InitialAddLiquidity() public {
        vm.prank(user);
        uint256 shares = amm.addLiquidity(100e18, 100e18);
        assertEq(shares, 100e18);
        assertEq(amm.reserve0(), 100e18);
    }

    function test_SubsequentAddLiquidity() public {
        vm.prank(user);
        amm.addLiquidity(100e18, 100e18);
        vm.prank(user2);
        uint256 shares = amm.addLiquidity(50e18, 50e18);
        assertEq(shares, 50e18);
    }

    function test_RemoveLiquidityFull() public {
        vm.startPrank(user);
        amm.addLiquidity(100e18, 100e18);
        amm.removeLiquidity(100e18);
        vm.stopPrank();
        assertEq(amm.reserve0(), 0);
    }

    function test_RemoveLiquidityPartial() public {
        vm.startPrank(user);
        amm.addLiquidity(100e18, 100e18);
        amm.removeLiquidity(50e18);
        vm.stopPrank();
        assertEq(amm.reserve0(), 50e18);
    }

    function test_Revert_AddLiquidityZero() public {
        vm.prank(user);
        vm.expectRevert("Insufficient liquidity minted");
        amm.addLiquidity(0, 0);
    }

    function test_Swap0to1() public {
        vm.startPrank(user);
        amm.addLiquidity(100e18, 100e18);
        uint256 out = amm.swap(address(token0), 10e18, 0);
        assertTrue(out > 0);
        vm.stopPrank();
    }

    function test_Swap1to0() public {
        vm.startPrank(user);
        amm.addLiquidity(100e18, 100e18);
        uint256 out = amm.swap(address(token1), 10e18, 0);
        assertTrue(out > 0);
        vm.stopPrank();
    }

    function test_ConstantProductIncreases() public {
        vm.startPrank(user);
        amm.addLiquidity(100e18, 100e18);
        uint256 k1 = amm.reserve0() * amm.reserve1();
        amm.swap(address(token0), 10e18, 0);
        uint256 k2 = amm.reserve0() * amm.reserve1();
        assertTrue(k2 > k1);
        vm.stopPrank();
    }

    function test_SlippageProtectionRevert() public {
        vm.startPrank(user);
        amm.addLiquidity(100e18, 100e18);
        uint256 expected = amm.getAmountOut(10e18, 100e18, 100e18);
        vm.expectRevert("Slippage: Output too low");
        amm.swap(address(token0), 10e18, expected + 1);
        vm.stopPrank();
    }

    function test_Revert_SwapInvalidToken() public {
        vm.prank(user);
        vm.expectRevert("Invalid token");
        amm.swap(address(0xdead), 10e18, 0);
    }

    function test_RevertWhen_SwapAmountIsZero() public {
        vm.startPrank(user);
        amm.addLiquidity(100e18, 100e18);
        vm.expectRevert("Inadequate input amount");
        amm.swap(address(token0), 0, 0);
        vm.stopPrank();
    }

    function test_HighPriceImpactSwap() public {
        vm.startPrank(user);
        amm.addLiquidity(10e18, 10e18);
        uint256 out = amm.swap(address(token0), 1000e18, 0);
        assertTrue(out < 10e18);
        vm.stopPrank();
    }

    function test_ImbalancedLiquidityProvision() public {
        vm.prank(user);
        amm.addLiquidity(100e18, 100e18); 
        vm.prank(user2);
        uint256 shares = amm.addLiquidity(100e18, 200e18);
        assertEq(shares, 100e18); 
    }

    function test_LPTokenOwnershipSecurity() public {
        LPToken lp = amm.lpToken();
        vm.expectRevert();
        lp.mint(user, 1000);
    }

    function testFuzz_Swap(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e6, 5000e18);
        vm.startPrank(user);
        amm.addLiquidity(10000e18, 10000e18);
        uint256 out = amm.getAmountOut(amountIn, 10000e18, 10000e18);
        amm.swap(address(token0), amountIn, out);
        vm.stopPrank();
    }
}