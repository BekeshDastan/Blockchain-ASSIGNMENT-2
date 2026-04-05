// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Router {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
}

contract ForkTest is Test {
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IUniswapV2Router constant ROUTER = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    uint256 mainnetFork;

    function setUp() public {
        string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
        
        mainnetFork = vm.createSelectFork(rpcUrl);
    }

    function test_ReadUSDCTotalSupply() public view {
        uint256 totalSupply = USDC.totalSupply();
        
        assertGt(totalSupply, 0, "USDC total supply should be greater than 0");
        
        console.log("USDC Total Supply:", totalSupply);
    }

    function test_UniswapV2Swap() public {
        address myUser = address(1);
        
        vm.deal(myUser, 10 ether); 

        vm.startPrank(myUser); 

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(USDC);

        uint256 usdcBalanceBefore = USDC.balanceOf(myUser);
        console.log("USDC balance BEFORE swap:", usdcBalanceBefore);

        ROUTER.swapExactETHForTokens{value: 1 ether}(
            0, 
            path,
            myUser,
            block.timestamp + 1000 
        );

        uint256 usdcBalanceAfter = USDC.balanceOf(myUser);
        console.log("USDC balance AFTER swap:", usdcBalanceAfter);

        vm.stopPrank();

        assertGt(usdcBalanceAfter, usdcBalanceBefore, "Swap failed: no USDC received");
        console.log("Net USDC received:", usdcBalanceAfter - usdcBalanceBefore);
    }
}