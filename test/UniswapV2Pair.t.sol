// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ERC20 } from "../src/test/ERC20.sol";
import { UniswapV2Pair } from "../src/UniswapV2Pair.sol";
import { UniswapV2Factory } from "../src/UniswapV2Factory.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Math as UniswapMath } from "../src/libraries/Math.sol";
import { UD60x18, ud60x18 } from "@prb/math/UD60x18.sol";
import { FlashBorrower } from "../src/helpers/FlashBorrower.sol";
import { IERC3156FlashLender } from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract UniswapV2PairTest is Test {
    UniswapV2Pair private _uniswapV2Pair;
    UniswapV2Factory private _uniswapV2Factory;
    FlashBorrower private _flashBorrower;

    address private _tokenA;
    address private _tokenB;
    address private _token0;
    address private _token1;
    address private _pair;

    // type(uint112).max / (1 * 10 ** 18)
    uint256 private constant UINT112_MAX_TOKENS = 5_192_296_858_534_827;
    // type(uint256).max / (1 * 10 ** 18)
    uint256 private constant UINT256_MAX_TOKENS = 115_792_089_237_316_195_423_570_985;
    uint256 private constant TOTAL_SUPPLY = UINT256_MAX_TOKENS * 10 ** 18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    event LoanTaken(address indexed lender, address indexed token, uint256 amountBorrowed);
    event LoanIssued(address indexed borrower, address indexed token, uint256 amountBorrowed);

    constructor() {
        _tokenA = address(new ERC20(TOTAL_SUPPLY));
        _tokenB = address(new ERC20(TOTAL_SUPPLY));
        (_token0, _token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        _uniswapV2Factory = new UniswapV2Factory(address(this));
        _pair = _uniswapV2Factory.createPair(_tokenA, _tokenB);
        _uniswapV2Pair = UniswapV2Pair(_pair);
        _flashBorrower = new FlashBorrower(IERC3156FlashLender(address(_uniswapV2Pair)));
    }

    function testInitialize() public {
        vm.prank(address(_uniswapV2Factory));

        _uniswapV2Pair.initialize(_token0, _token1);

        assertEq(_token0, _uniswapV2Pair.token0(), "Token 0 was not initialized");
        assertEq(_token1, _uniswapV2Pair.token1(), "Token 1 was not initialized");
    }

    function testRevertInitialize() public {
        vm.expectRevert("UniswapV2: FORBIDDEN");

        _uniswapV2Pair.initialize(_token0, _token1);
    }

    function testMint(uint256 token0Count, uint256 token1Count) public {
        vm.assume(token0Count > 0);
        vm.assume(token1Count > 0);
        vm.assume(token0Count <= UINT112_MAX_TOKENS);
        vm.assume(token1Count <= UINT112_MAX_TOKENS);

        uint256 token0Amount = token0Count * 10 ** 18;
        uint256 token1Amount = token1Count * 10 ** 18;
        uint256 expectedLiquidity = UniswapMath.sqrt(token0Amount * token1Amount) - _uniswapV2Pair.MINIMUM_LIQUIDITY();
        uint256 initialPoolBalanceToken0 = ERC20(_token0).balanceOf(address(_pair));
        uint256 initialPoolBalanceToken1 = ERC20(_token1).balanceOf(address(_pair));
        uint256 initialDeployerBalanceToken0 = ERC20(_token0).balanceOf(address(this));
        uint256 initialDeployerBalanceToken1 = ERC20(_token1).balanceOf(address(this));

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        uint256 poolBalanceToken0 = ERC20(_token0).balanceOf(address(_pair));
        uint256 poolBalanceToken1 = ERC20(_token1).balanceOf(address(_pair));
        uint256 deployerBalanceToken0 = ERC20(_token0).balanceOf(address(this));
        uint256 deployerBalanceToken1 = ERC20(_token1).balanceOf(address(this));
        (uint112 _reserve0, uint112 _reserve1,) = _uniswapV2Pair.getReserves();

        assertEq(initialPoolBalanceToken0 + token0Amount, poolBalanceToken0);
        assertEq(initialPoolBalanceToken1 + token1Amount, poolBalanceToken1);
        assertEq(initialDeployerBalanceToken0 - token0Amount, deployerBalanceToken0);
        assertEq(initialDeployerBalanceToken1 - token1Amount, deployerBalanceToken1);

        vm.expectEmit(true, true, true, true, address(_uniswapV2Pair));

        emit Sync(uint112(poolBalanceToken0), uint112(poolBalanceToken1));

        vm.expectEmit(true, true, true, true, address(_uniswapV2Pair));

        emit Mint(address(this), poolBalanceToken0 - _reserve0, poolBalanceToken1 - _reserve1);

        uint256 liquidity = _uniswapV2Pair.mint(address(this));

        assertEq(expectedLiquidity, liquidity);
    }

    function testBurn(uint256 token0Count, uint256 token1Count) public {
        vm.assume(token0Count > 0);
        vm.assume(token1Count > 0);
        vm.assume(token0Count <= UINT112_MAX_TOKENS);
        vm.assume(token1Count <= UINT112_MAX_TOKENS);

        uint256 token0Amount = token0Count * 10 ** 18;
        uint256 token1Amount = token1Count * 10 ** 18;
        uint256 minimumLiquidity = _uniswapV2Pair.MINIMUM_LIQUIDITY();
        uint256 expectedLiquidity = Math.sqrt(token0Amount * token1Amount) - minimumLiquidity;

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        uint256 liquidity = _uniswapV2Pair.mint(address(this));

        _uniswapV2Pair.transfer(address(_pair), expectedLiquidity);

        uint256 initialPoolBalanceToken0 = ERC20(_token0).balanceOf(address(_pair));
        uint256 initialPoolBalanceToken1 = ERC20(_token1).balanceOf(address(_pair));
        uint256 _totalSupply = _uniswapV2Pair.totalSupply();
        uint256 expectedtoken0Amount = (liquidity * initialPoolBalanceToken0) / _totalSupply;
        uint256 expectedtoken1Amount = (liquidity * initialPoolBalanceToken1) / _totalSupply;

        vm.expectEmit(true, true, true, true, address(_uniswapV2Pair));

        emit Transfer(address(_uniswapV2Pair), address(0), liquidity);

        vm.expectEmit(true, true, true, true, address(_token0));

        emit Transfer(address(_uniswapV2Pair), address(this), expectedtoken0Amount);

        vm.expectEmit(true, true, true, true, address(_token1));

        emit Transfer(address(_uniswapV2Pair), address(this), expectedtoken1Amount);

        vm.expectEmit(true, true, true, true, address(_uniswapV2Pair));

        emit Sync(
            uint112(initialPoolBalanceToken0 - expectedtoken0Amount),
            uint112(initialPoolBalanceToken1 - expectedtoken1Amount)
        );

        vm.expectEmit(true, true, true, true, address(_uniswapV2Pair));

        emit Burn(address(this), expectedtoken0Amount, expectedtoken1Amount, address(this));

        _uniswapV2Pair.burn(address(this));

        assertEq(_uniswapV2Pair.balanceOf(address(this)), 0);
        assertEq(_uniswapV2Pair.totalSupply(), minimumLiquidity);
    }

    function testRevertBurn(uint256 token0Count, uint256 token1Count) public {
        vm.assume(token0Count > 0);
        vm.assume(token1Count > 0);
        vm.assume(token0Count <= UINT112_MAX_TOKENS);
        vm.assume(token1Count <= UINT112_MAX_TOKENS);

        uint256 token0Amount = token0Count * 10 ** 18;
        uint256 token1Amount = token1Count * 10 ** 18;

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        _uniswapV2Pair.mint(address(this));

        vm.expectRevert("UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED");

        _uniswapV2Pair.burn(address(this));
    }

    function testSwap() public {
        (,, uint256 expectedOutputAmount, uint256 swapAmount) = _addLiquidityForSwap();

        (uint112 _reserve0, uint112 _reserve1,) = _uniswapV2Pair.getReserves();

        vm.expectEmit(true, true, true, true, address(_token1));

        emit Transfer(address(_uniswapV2Pair), address(this), expectedOutputAmount);

        vm.expectEmit(true, true, true, true, address(_uniswapV2Pair));

        emit Sync(uint112(_reserve0 + swapAmount), uint112(_reserve1 - expectedOutputAmount));

        vm.expectEmit();

        emit Swap(address(this), swapAmount, 0, 0, expectedOutputAmount, address(this));

        _uniswapV2Pair.swap(0, expectedOutputAmount, address(this));
    }

    function testRevertSwapInsufficientOutputAmount() public {
        uint256 expectedOutputAmount = 0;

        _addLiquidityForSwap();

        vm.expectRevert("UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT");

        _uniswapV2Pair.swap(0, expectedOutputAmount, address(this));
    }

    function testRevertSwapInsufficientLiquidity() public {
        uint256 expectedOutputAmount = 1000 * 10 ** 18;

        _addLiquidityForSwap();

        vm.expectRevert("UniswapV2: INSUFFICIENT_LIQUIDITY");

        _uniswapV2Pair.swap(0, expectedOutputAmount, address(this));
    }

    function testRevertSwapInvalidTo() public {
        (,, uint256 expectedOutputAmount,) = _addLiquidityForSwap();

        vm.expectRevert("UniswapV2: INVALID_TO");

        _uniswapV2Pair.swap(0, expectedOutputAmount, address(_token0));

        vm.expectRevert("UniswapV2: INVALID_TO");

        _uniswapV2Pair.swap(0, expectedOutputAmount, address(_token1));
    }

    function testRevertSwapInsufficientInputAmount() public {
        uint256 token0Amount = 5 * 10 ** 18;
        uint256 token1Amount = 10 * 10 ** 18;
        uint256 expectedOutputAmount = 1_662_497_915_624_478_906;

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        _uniswapV2Pair.mint(address(this));

        vm.expectRevert("UniswapV2: INSUFFICIENT_INPUT_AMOUNT");

        _uniswapV2Pair.swap(0, expectedOutputAmount, address(this));
    }

    function testRevertSwapK() public {
        uint256 expectedOutputAmount = 1_662_497_915_624_478_906 + 1;

        _addLiquidityForSwap();

        vm.expectRevert("UniswapV2: K");

        _uniswapV2Pair.swap(0, expectedOutputAmount, address(this));
    }

    function testFlashLoan(uint256 borrowedAmount) public {
        vm.assume(borrowedAmount <= ERC20(_token0).balanceOf(address(_uniswapV2Pair)));

        uint256 fee = _uniswapV2Pair.flashFee(_token0, borrowedAmount);

        _addLiquidityForSwap();

        // Send some tokens to the borrower so they have enough to pay the fee
        ERC20(_token0).transfer(address(_flashBorrower), borrowedAmount * 2 + 1);

        vm.expectEmit(true, true, true, true, _token0);

        emit Transfer(address(_uniswapV2Pair), address(_flashBorrower), borrowedAmount);

        vm.expectEmit(true, true, true, true, address(_uniswapV2Pair));

        emit LoanIssued(address(_flashBorrower), _token0, borrowedAmount);

        vm.expectEmit(true, true, true, true, address(_flashBorrower));

        emit LoanTaken(address(_uniswapV2Pair), _token0, borrowedAmount);

        vm.expectEmit(true, true, true, true, _token0);

        emit Transfer(address(_flashBorrower), address(_uniswapV2Pair), borrowedAmount + fee);

        _flashBorrower.flashBorrow(_token0, borrowedAmount);
    }

    function testRevertFlashLoanUnsupportedCurrency(uint256 borrowedAmount, address unsupportedCurrency) public {
        vm.assume(borrowedAmount <= ERC20(_token0).balanceOf(address(_uniswapV2Pair)));
        vm.assume(unsupportedCurrency != _token0);
        vm.assume(unsupportedCurrency != _token1);

        _addLiquidityForSwap();

        vm.expectRevert("FlashLender: Unsupported currency");

        _uniswapV2Pair.flashLoan(IERC3156FlashBorrower(_flashBorrower), unsupportedCurrency, borrowedAmount, "");
    }

    function testRevertFlashFeeUnsupportedCurrency(uint256 borrowedAmount, address unsupportedCurrency) public {
        vm.assume(borrowedAmount <= ERC20(_token0).balanceOf(address(_uniswapV2Pair)));
        vm.assume(unsupportedCurrency != _token0);
        vm.assume(unsupportedCurrency != _token1);

        _addLiquidityForSwap();

        vm.expectRevert("FlashLender: Unsupported currency");

        _uniswapV2Pair.flashFee(unsupportedCurrency, borrowedAmount);
    }

    function testMaxFlashLoan(uint256 token0Count, uint256 token1Count) public {
        vm.assume(token0Count > 0);
        vm.assume(token1Count > 0);
        vm.assume(token0Count <= UINT112_MAX_TOKENS);
        vm.assume(token1Count <= UINT112_MAX_TOKENS);

        uint256 token0Amount = token0Count * 10 ** 18;
        uint256 token1Amount = token1Count * 10 ** 18;

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        _uniswapV2Pair.mint(address(this));

        uint256 maxAmount0 = _uniswapV2Pair.maxFlashLoan(address(_token0));
        uint256 maxAmount1 = _uniswapV2Pair.maxFlashLoan(address(_token1));

        assertEq(token0Amount, maxAmount0);
        assertEq(token1Amount, maxAmount1);
    }

    function testRevertMaxFlashLoanUnsupportedLoan(uint256 token0Count, uint256 token1Count, address unsupportedToken)
        public
    {
        vm.assume(unsupportedToken != _token0);
        vm.assume(unsupportedToken != _token1);
        vm.assume(token0Count > 0);
        vm.assume(token1Count > 0);
        vm.assume(token0Count <= UINT112_MAX_TOKENS);
        vm.assume(token1Count <= UINT112_MAX_TOKENS);

        uint256 token0Amount = token0Count * 10 ** 18;
        uint256 token1Amount = token1Count * 10 ** 18;

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        _uniswapV2Pair.mint(address(this));

        uint256 maxAmount = _uniswapV2Pair.maxFlashLoan(unsupportedToken);

        assertEq(maxAmount, 0);
    }

    function testSkim(uint256 token0Count, uint256 token1Count) public {
        vm.assume(token0Count > 0);
        vm.assume(token1Count > 0);
        vm.assume(token0Count <= UINT112_MAX_TOKENS);
        vm.assume(token1Count <= UINT112_MAX_TOKENS);

        uint256 token0Amount = token0Count * 10 ** 18;
        uint256 token1Amount = token1Count * 10 ** 18;

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        _uniswapV2Pair.mint(address(this));

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        uint256 poolBalanceToken0 = ERC20(_token0).balanceOf(address(_pair));
        uint256 poolBalanceToken1 = ERC20(_token1).balanceOf(address(_pair));
        (uint112 _reserve0, uint112 _reserve1,) = _uniswapV2Pair.getReserves();

        vm.expectEmit(true, true, true, true, address(_token0));

        emit Transfer(address(_uniswapV2Pair), address(this), poolBalanceToken0 - _reserve0);

        vm.expectEmit(true, true, true, true, address(_token1));

        emit Transfer(address(_uniswapV2Pair), address(this), poolBalanceToken1 - _reserve1);

        _uniswapV2Pair.skim(address(this));
    }

    function testSync(uint256 token0Count, uint256 token1Count) public {
        vm.assume(token0Count > 0);
        vm.assume(token1Count > 0);
        vm.assume(token0Count < UINT112_MAX_TOKENS);
        vm.assume(token1Count < UINT112_MAX_TOKENS);

        uint256 token0Amount = token0Count * 10 ** 18;
        uint256 token1Amount = token1Count * 10 ** 18;

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        _uniswapV2Pair.mint(address(this));

        ERC20(_token0).transfer(address(_pair), 1);
        ERC20(_token1).transfer(address(_pair), 1);

        uint256 poolBalanceToken0 = ERC20(_token0).balanceOf(address(_pair));
        uint256 poolBalanceToken1 = ERC20(_token1).balanceOf(address(_pair));
        (uint112 _reserve0BeforeSync, uint112 _reserve1BeforeSync,) = _uniswapV2Pair.getReserves();

        assertNotEq(poolBalanceToken0, _reserve0BeforeSync);
        assertNotEq(poolBalanceToken1, _reserve1BeforeSync);

        vm.expectEmit(true, true, true, true, address(_uniswapV2Pair));

        emit Sync(uint112(poolBalanceToken0), uint112(poolBalanceToken1));

        _uniswapV2Pair.sync();

        (uint112 _reserve0AfterSync, uint112 _reserve1AfterSync,) = _uniswapV2Pair.getReserves();

        assertEq(poolBalanceToken0, _reserve0AfterSync);
        assertEq(poolBalanceToken1, _reserve1AfterSync);
    }

    function testRevertSyncOverflow() public {
        uint256 token0Amount = UINT112_MAX_TOKENS * 10 ** 18;
        uint256 token1Amount = UINT112_MAX_TOKENS * 10 ** 18;

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        _uniswapV2Pair.mint(address(this));

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        vm.expectRevert("UniswapV2: OVERFLOW");

        _uniswapV2Pair.sync();
    }

    function testFeeToOn(address feeTo) public {
        vm.assume(feeTo != address(this));
        vm.assume(feeTo != address(0));

        _uniswapV2Factory.setFeeTo(feeTo);

        uint256 token0Amount = 1000 * 10 ** 18;
        uint256 token1Amount = 1000 * 10 ** 18;

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        _uniswapV2Pair.mint(address(this));

        uint256 swapAmount = 1 * 10 ** 18;
        uint256 expectedOutputAmount = 996006981039903216;

        ERC20(_token1).transfer(address(_pair), swapAmount);

        _uniswapV2Pair.swap(expectedOutputAmount, 0, address(this));

        uint256 expectedLiquidity = 1000 * 10 ** 18;

        _uniswapV2Pair.transfer(address(_pair), expectedLiquidity - _uniswapV2Pair.MINIMUM_LIQUIDITY());

        _uniswapV2Pair.burn(address(this));

        assertEq(_uniswapV2Pair.totalSupply(), _uniswapV2Pair.MINIMUM_LIQUIDITY() + 249750499251388);
        assertEq(_uniswapV2Pair.balanceOf(feeTo), 249750499251388);
        // using 1000 here instead of the symbolic MINIMUM_LIQUIDITY because the amounts only happen to be equal...
        // ...because the initial liquidity amounts were equal
        assertEq(ERC20(_token0).balanceOf(address(_pair)), 1000 + 249501683697445);
        assertEq(ERC20(_token1).balanceOf(address(_pair)), 1000 + 250000187312969);
    }

    function testPriceCumulativeLast() public {
        uint112 token0Amount = 3 * 10 ** 18;
        uint112 token1Amount = 3 * 10 ** 18;

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        _uniswapV2Pair.mint(address(this));

        (uint112 _reserve0, uint112 _reserve1, uint32 originalBlockTimestampLast) = _uniswapV2Pair.getReserves();

        vm.warp(originalBlockTimestampLast + 1);

        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - originalBlockTimestampLast;

        _uniswapV2Pair.sync();

        uint256 initialPriceToken0 = ud60x18(_reserve1).mul(ud60x18(112e18).exp2()).div(
            ud60x18(_reserve0).mul(ud60x18(1e36))
        ).intoUint256() * timeElapsed;
        uint256 initialPriceToken1 = ud60x18(_reserve0).mul(ud60x18(112e18).exp2()).div(
            ud60x18(_reserve1).mul(ud60x18(1e36))
        ).intoUint256() * timeElapsed;

        (,, uint32 blockTimestampLast) = _uniswapV2Pair.getReserves();

        assertEq(_uniswapV2Pair.price0CumulativeLast(), initialPriceToken0);
        assertEq(_uniswapV2Pair.price1CumulativeLast(), initialPriceToken1);
        assertEq(blockTimestampLast, originalBlockTimestampLast + 1);

        uint256 swapAmount = 3 * 10 ** 18;

        ERC20(_token0).transfer(address(_pair), swapAmount);

        vm.warp(originalBlockTimestampLast + 10);

        _uniswapV2Pair.swap(0, 1 * 10 ** 18, address(this));

        (,, blockTimestampLast) = _uniswapV2Pair.getReserves();

        assertEq(_uniswapV2Pair.price0CumulativeLast(), initialPriceToken0 * 10);
        assertEq(_uniswapV2Pair.price1CumulativeLast(), initialPriceToken1 * 10);
        assertEq(blockTimestampLast, originalBlockTimestampLast + 10);

        vm.warp(originalBlockTimestampLast + 20);

        _uniswapV2Pair.sync();

        uint112 newReserve0 = 6 * 10 ** 18;
        uint112 newReserve1 = 2 * 10 ** 18;
        uint256 newPriceToken0 = ud60x18(newReserve1).mul(ud60x18(112e18).exp2()).div(
            ud60x18(newReserve0).mul(ud60x18(1e36))
        ).intoUint256() * timeElapsed;
        uint256 newPriceToken1 = ud60x18(newReserve0).mul(ud60x18(112e18).exp2()).div(
            ud60x18(newReserve1).mul(ud60x18(1e36))
        ).intoUint256() * timeElapsed;
        (,, blockTimestampLast) = _uniswapV2Pair.getReserves();

        assertEq(_uniswapV2Pair.price0CumulativeLast(), initialPriceToken0 * 10 + newPriceToken0 * 10);
        assertEq(_uniswapV2Pair.price1CumulativeLast(), initialPriceToken1 * 10 + newPriceToken1 * 10);
        assertEq(blockTimestampLast, originalBlockTimestampLast + 20);
    }

    function _addLiquidityForSwap()
        private
        returns (uint256 token0Amount, uint256 token1Amount, uint256 expectedOutputAmount, uint256 swapAmount)
    {
        token0Amount = 5 * 10 ** 18;
        token1Amount = 10 * 10 ** 18;
        expectedOutputAmount = 1_662_497_915_624_478_906;
        swapAmount = 1 * 10 ** 18;

        ERC20(_token0).transfer(address(_pair), token0Amount);
        ERC20(_token1).transfer(address(_pair), token1Amount);

        _uniswapV2Pair.mint(address(this));

        ERC20(_token0).transfer(address(_pair), swapAmount);
    }

    function _getMintFee(uint112 _reserve0, uint112 _reserve1) private view returns (uint256 liquidity) {
        uint256 _kLast = _uniswapV2Pair.kLast();

        console.log(_kLast);

        if (_kLast != 0) {
            uint256 rootK = UniswapMath.sqrt(uint256(_reserve0) * _reserve1);

            console.log(rootK);

            uint256 rootKLast = UniswapMath.sqrt(_kLast);

            console.log(rootKLast);

            if (rootK > rootKLast) {
                uint256 numerator = _uniswapV2Pair.totalSupply() * (rootK - rootKLast);
                uint256 denominator = (rootK * 5) + rootKLast;
                liquidity = numerator / denominator;
            }
        }
    }
}
