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

        console.log(string.concat("Constant Product Without Fees: "));
        console.log(constantProductWithoutFees);

        uint256 totalFeeAmount = constantProduct - constantProductWithoutFees;

        console.log(string.concat("Total Fee Amount: "));
        console.log(totalFeeAmount);

        uint256 constantProductWithoutFeeTo =
            _uniswapV2PairHandler.token0LiquidityWithoutFeeTo() * _uniswapV2PairHandler.token1LiquidityWithoutFeeTo();

        console.log(string.concat("Constant Product Without FeeTo: "));
        console.log(constantProductWithoutFeeTo);

        uint256 kLast = _uniswapV2Pair.kLast();

        console.log(string.concat("kLast: "));
        console.log(kLast);

        uint256 k = kLast < constantProduct ? kLast + totalFeeAmount + constantProductWithoutFeeTo : kLast;

        assertEq(constantProduct, k);
    }
}
