// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LPToken.sol";

contract AMM {
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    LPToken public immutable lpToken;

    uint256 public reserve0;
    uint256 public reserve1;

    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 lpMinted);
    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 lpBurned);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        lpToken = new LPToken();
    }

    function addLiquidity(uint256 amount0Desired, uint256 amount1Desired) external returns (uint256 shares) {
        token0.transferFrom(msg.sender, address(this), amount0Desired);
        token1.transferFrom(msg.sender, address(this), amount1Desired);

        uint256 _totalSupply = lpToken.totalSupply();
        if (_totalSupply == 0) {
            shares = _sqrt(amount0Desired * amount1Desired);
        } else {
            shares = _min(
                (amount0Desired * _totalSupply) / reserve0,
                (amount1Desired * _totalSupply) / reserve1
            );
        }

        require(shares > 0, "Insufficient liquidity minted");
        lpToken.mint(msg.sender, shares);
        _updateReserves();
        
        emit LiquidityAdded(msg.sender, amount0Desired, amount1Desired, shares);
    }

    function removeLiquidity(uint256 shares) external returns (uint256 amount0, uint256 amount1) {
        uint256 _totalSupply = lpToken.totalSupply();
        amount0 = (shares * reserve0) / _totalSupply;
        amount1 = (shares * reserve1) / _totalSupply;

        lpToken.burn(msg.sender, shares);
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);

        _updateReserves();
        emit LiquidityRemoved(msg.sender, amount0, amount1, shares);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        require(tokenIn == address(token0) || tokenIn == address(token1), "Invalid token");
        bool isToken0 = tokenIn == address(token0);
        
        (IERC20 tIn, IERC20 tOut, uint256 resIn, uint256 resOut) = isToken0 
            ? (token0, token1, reserve0, reserve1) 
            : (token1, token0, reserve1, reserve0);

        tIn.transferFrom(msg.sender, address(this), amountIn);

        amountOut = getAmountOut(amountIn, resIn, resOut);
        require(amountOut >= minAmountOut, "Slippage: Output too low");

        tOut.transfer(msg.sender, amountOut);
        _updateReserves();
        
        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    function getAmountOut(uint256 amountIn, uint256 resIn, uint256 resOut) public pure returns (uint256) {
        require(amountIn > 0, "Inadequate input amount");
        require(resIn > 0 && resOut > 0, "Inadequate liquidity");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * resOut;
        uint256 denominator = (resIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    function _updateReserves() internal {
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x <= y ? x : y;
    }
}