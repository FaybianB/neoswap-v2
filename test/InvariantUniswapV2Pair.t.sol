// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { console } from "forge-std/console.sol";
import { ERC20Mock as ERC20 } from "../src/test/ERC20Mock.sol";
import { UniswapV2Pair } from "../src/UniswapV2Pair.sol";
import { UniswapV2Factory } from "../src/UniswapV2Factory.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Math as UniswapMath } from "../src/libraries/Math.sol";
import { FlashBorrower } from "../src/helpers/FlashBorrower.sol";
import { IERC3156FlashLender } from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import { ERC3156FlashBorrowerMock } from "@openzeppelin/contracts/mocks/ERC3156FlashBorrowerMock.sol";
import { UQ112x112 } from "../src/libraries/UQ112x112.sol";
import { UniswapV2PairHandler } from "./handler/UniswapV2PairHandler.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract InvariantUniswapV2PairTest is Test {
    using UQ112x112 for uint224;

    UniswapV2Pair private _uniswapV2Pair;
    UniswapV2Factory private _uniswapV2Factory;
    FlashBorrower private _flashBorrower;
    UniswapV2PairHandler private _uniswapV2PairHandler;

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

    function setUp() external {
        _tokenA = address(new ERC20(TOTAL_SUPPLY));
        _tokenB = address(new ERC20(TOTAL_SUPPLY));
        (_token0, _token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        _uniswapV2Factory = new UniswapV2Factory(address(this));
        _pair = _uniswapV2Factory.createPair(_tokenA, _tokenB);
        _uniswapV2Pair = UniswapV2Pair(_pair);
        _flashBorrower = new FlashBorrower(IERC3156FlashLender(address(_uniswapV2Pair)));
        _uniswapV2PairHandler =
            new UniswapV2PairHandler(this, _uniswapV2Factory, _uniswapV2Pair, _flashBorrower, _token0, _token1);

        targetContract(address(_uniswapV2PairHandler));
    }

    function invariant_total_liquidity() external {
        if (_uniswapV2Factory.feeTo() == address(0)) {
            return;
        }

        uint256 poolBalanceToken0 = ERC20(_token0).balanceOf(address(_pair));
        uint256 poolBalanceToken1 = ERC20(_token1).balanceOf(address(_pair));
        uint256 constantProduct = poolBalanceToken0 * poolBalanceToken1;
        uint256 constantProductWithoutFees =
            (poolBalanceToken0 - _uniswapV2PairHandler.accumulatedFees()) * poolBalanceToken1;
        uint256 totalFeeAmount = constantProduct - constantProductWithoutFees;
        uint256 constantProductWithoutFeeTo =
            _uniswapV2PairHandler.token0LiquidityWithoutFeeTo() * _uniswapV2PairHandler.token1LiquidityWithoutFeeTo();
        uint256 kLast = _uniswapV2Pair.kLast();
        uint256 k = kLast < constantProduct ? kLast + totalFeeAmount + constantProductWithoutFeeTo : kLast;

        assertEq(constantProduct, k);
    }

    function invariant_constant_product_formula() external {
        assertEq(_uniswapV2PairHandler.constantProductBeforeSwap(), _uniswapV2PairHandler.constantProductAfterSwap());
    }

    function invariant_token_ratio() external {
        uint256 _totalSupply = _uniswapV2Pair.totalSupply();

        if (_totalSupply == 0) {
            return;
        }

        _uniswapV2Pair.sync();

        uint256 token0Count = 10;
        uint256 token1Count = 10;
        uint256 token0Amount = token0Count * 10 ** 18;
        uint256 token1Amount = token1Count * 10 ** 18;
        (uint112 reserve0, uint112 reserve1,) = _uniswapV2Pair.getReserves();
        uint256 fee = _mintFee(reserve0, reserve1);
        _totalSupply += fee;
        uint256 expectedLiquidity =
            UniswapMath.min((token0Amount * _totalSupply) / reserve0, (token1Amount * _totalSupply) / reserve1);
        (,, uint256 liquidity) = _uniswapV2PairHandler.addLiquidity(token0Count, token1Count);

        assertEq(expectedLiquidity, liquidity);
    }

    function invariant_no_token_creation_or_destruction() external {
        uint256 totalSupplyToken0 = ERC20(_token0).totalSupply();
        uint256 totalSupplyToken1 = ERC20(_token1).totalSupply();
        uint256 poolBalanceToken0 = ERC20(_token0).balanceOf(address(_pair));
        uint256 poolBalanceToken1 = ERC20(_token1).balanceOf(address(_pair));
        uint256 deployerBalanceToken0 = ERC20(_token0).balanceOf(address(this));
        uint256 deployerBalanceToken1 = ERC20(_token1).balanceOf(address(this));
        uint256 flashBorrowerBalanceToken0 = ERC20(_token0).balanceOf(address(_flashBorrower));
        uint256 flashBorrowerBalanceToken1 = ERC20(_token1).balanceOf(address(_flashBorrower));
        uint256 sumToken0 = deployerBalanceToken0 + poolBalanceToken0 + flashBorrowerBalanceToken0;
        uint256 sumToken1 = deployerBalanceToken1 + poolBalanceToken1 + flashBorrowerBalanceToken1;

        for (uint256 i = 0; i < _uniswapV2PairHandler.feeReceiversCount(); i++) {
            sumToken0 += ERC20(_token0).balanceOf(address(_uniswapV2PairHandler.feeReceivers(i)));
            sumToken1 += ERC20(_token1).balanceOf(address(_uniswapV2PairHandler.feeReceivers(i)));
        }

        assertEq(sumToken0, totalSupplyToken0);
        assertEq(sumToken1, totalSupplyToken1);
    }

    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (uint256 fee) {
        address feeTo = _uniswapV2Factory.feeTo();
        bool feeOn = feeTo != address(0);
        uint256 _kLast = _uniswapV2Pair.kLast();
        uint256 _totalSupply = _uniswapV2Pair.totalSupply();

        if (feeOn) {
            if (_kLast != 0) {
                // Calculate the square root of the product of the reserves
                uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                // Calculate the square root of kLast
                uint256 rootKLast = Math.sqrt(_kLast);

                if (rootK > rootKLast) {
                    // Calculate the numerator for the liquidity to mint
                    uint256 numerator = _totalSupply * (rootK - rootKLast);
                    // Calculate the denominator for the liquidity to mint
                    uint256 denominator = (rootK * 5) + rootKLast;
                    // Calculate the liquidity to mint
                    fee = numerator / denominator;
                }
            }
        }
    }
}
