// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { UniswapV2Pair } from "../../src/UniswapV2Pair.sol";
import { ERC20Mock as ERC20 } from "../../src/test/ERC20Mock.sol";
import { FlashBorrower } from "../../src/helpers/FlashBorrower.sol";
import { InvariantUniswapV2PairTest } from "../InvariantUniswapV2Pair.t.sol";
import { UniswapV2Factory } from "../../src/UniswapV2Factory.sol";
import { Math as UniswapMath } from "../../src/libraries/Math.sol";

contract UniswapV2PairHandler is Test {
    address private _token0;
    address private _token1;
    address public feeReceiver = makeAddr("feeReceiver");
    address public skimReceiver = makeAddr("skimReceiver");
    address public burnReceiver = makeAddr("burnReceiver");
    address public swapReceiver = makeAddr("swapReceiver");

    UniswapV2Pair private _uniswapV2Pair;
    UniswapV2Factory private _uniswapV2Factory;
    FlashBorrower private _flashBorrower;
    InvariantUniswapV2PairTest private _invariantUniswapV2PairTest;

    // type(uint112).max / (1 * 10 ** 18)
    uint256 private constant UINT112_MAX_TOKENS = 5_192_296_858_534_827;
    // type(uint256).max / (1 * 10 ** 18)
    uint256 private constant UINT256_MAX_TOKENS = 115_792_089_237_316_195_423_570_985;
    uint256 private constant TOTAL_SUPPLY = UINT256_MAX_TOKENS * 10 ** 18;
    uint256 public accumulatedFees = 0;
    uint256 public token0LiquidityWithoutFeeTo = 0;
    uint256 public token1LiquidityWithoutFeeTo = 0;
    uint256 public constantProductBeforeSwap = 0;
    uint256 public constantProductAfterSwap = 0;
    uint256 public expectedAmount0In = 0;
    uint256 public expectedAmount1In = 0;
    uint256 public amount0In = 0;
    uint256 public amount1In = 0;

    constructor(
        InvariantUniswapV2PairTest invariantUniswapV2PairTest,
        UniswapV2Factory uniswapV2Factory,
        UniswapV2Pair uniswapV2Pair,
        FlashBorrower flashBorrower,
        address token0,
        address token1
    ) {
        _invariantUniswapV2PairTest = invariantUniswapV2PairTest;
        _uniswapV2Factory = uniswapV2Factory;
        _uniswapV2Pair = uniswapV2Pair;
        _flashBorrower = flashBorrower;
        _token0 = token0;
        _token1 = token1;
    }

    function flashBorrow(uint256 amount) external {
        vm.assume(amount <= ERC20(_token0).balanceOf(address(_uniswapV2Pair)));

        vm.prank(address(_invariantUniswapV2PairTest));

        // Send some tokens to the borrower so they have enough to pay the fee
        ERC20(_token0).transfer(address(_flashBorrower), amount * 2 + 1);

        accumulatedFees += _uniswapV2Pair.flashFee(_token0, amount);

        _flashBorrower.flashBorrow(_token0, amount);
    }

    function mint(address to) external {
        _uniswapV2Pair.mint(to);
    }

    function burn(address to) external {
        _uniswapV2Pair.burn(to == _invariantUniswapV2PairTest.tokenReceiver() ? to : burnReceiver);
    }

    function swap(uint256 amount0Out, uint256 amount1Out) external {
        uint256 poolBalanceToken0Before = ERC20(_token0).balanceOf(address(_uniswapV2Pair));
        uint256 poolBalanceToken1Before = ERC20(_token1).balanceOf(address(_uniswapV2Pair));

        vm.assume(amount0Out <= poolBalanceToken0Before);
        vm.assume(amount1Out <= poolBalanceToken1Before);

        constantProductBeforeSwap = poolBalanceToken0Before * poolBalanceToken1Before;
        (uint112 _reserve0, uint112 _reserve1,) = _uniswapV2Pair.getReserves();
        expectedAmount0In = _getAmountIn(amount1Out, _reserve0, _reserve1);
        expectedAmount1In = _getAmountIn(amount0Out, _reserve1, _reserve0);

        _uniswapV2Pair.swap(amount0Out, amount1Out, swapReceiver);

        uint256 poolBalanceToken0After = ERC20(_token0).balanceOf(address(_uniswapV2Pair));
        uint256 poolBalanceToken1After = ERC20(_token1).balanceOf(address(_uniswapV2Pair));
        constantProductAfterSwap = poolBalanceToken0After * poolBalanceToken1After;
        amount0In = poolBalanceToken0After - poolBalanceToken0Before;
        amount1In = poolBalanceToken1After - poolBalanceToken1Before;
    }

    function skim() external {
        _uniswapV2Pair.skim(skimReceiver);
    }

    function sync() external {
        _uniswapV2Pair.sync();
    }

    function setFeeTo() public {
        vm.prank(address(_invariantUniswapV2PairTest));

        _uniswapV2Factory.setFeeTo(feeReceiver);
    }

    function addLiquidity(uint256 token0Count, uint256 token1Count)
        public
        returns (uint256 token0Amount, uint256 token1Amount, uint256 liquidity)
    {
        token0Count = bound(token0Count, 1, UINT112_MAX_TOKENS / 5);
        token1Count = bound(token1Count, 1, UINT112_MAX_TOKENS / 5);
        token0Amount = token0Count * 10 ** 18;
        token1Amount = token1Count * 10 ** 18;

        vm.startPrank(address(_invariantUniswapV2PairTest));

        ERC20(_token0).transfer(address(_uniswapV2Pair), token0Amount);
        ERC20(_token1).transfer(address(_uniswapV2Pair), token1Amount);

        vm.stopPrank();

        if (_uniswapV2Factory.feeTo() == address(0)) {
            token0LiquidityWithoutFeeTo += token0Amount;
            token1LiquidityWithoutFeeTo += token1Amount;
        } else {
            token0LiquidityWithoutFeeTo = 0;
            token1LiquidityWithoutFeeTo = 0;
            accumulatedFees = 0;
        }

        liquidity = _uniswapV2Pair.mint(address(this));
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function _getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        private
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    receive() external payable { }
}
