// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { UniswapV2Pair } from "../../src/UniswapV2Pair.sol";
import { ERC20Mock as ERC20 } from "../../src/test/ERC20Mock.sol";
import { FlashBorrower } from "../../src/helpers/FlashBorrower.sol";
import { InvariantUniswapV2PairTest } from "../InvariantUniswapV2Pair.t.sol";
import { UniswapV2Factory } from "../../src/UniswapV2Factory.sol";

contract UniswapV2PairHandler is Test {
    address private _token0;
    address private _token1;

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

    function setFeeTo(address feeTo) public {
        vm.prank(address(_invariantUniswapV2PairTest));

        _uniswapV2Factory.setFeeTo(feeTo);
    }

    function addLiquidity(uint256 token0Count, uint256 token1Count)
        public
        returns (uint256 token0Amount, uint256 token1Amount)
    {
        token0Count = bound(token0Count, 1, UINT112_MAX_TOKENS);
        token1Count = bound(token1Count, 1, UINT112_MAX_TOKENS);
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

        _uniswapV2Pair.mint(address(this));
    }

    receive() external payable { }
}
