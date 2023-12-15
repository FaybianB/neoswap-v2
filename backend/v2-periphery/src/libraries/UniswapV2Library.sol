// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { IUniswapV2Pair } from "../../../v2-core/src/interfaces/IUniswapV2Pair.sol";

/**
 * @title UniswapV2Library
 * @dev This library is used for various Uniswap V2 functionalities.
 */
library UniswapV2Library {
    /**
     * @dev Sorts the token addresses in ascending order.
     * @param tokenA The first token address.
     * @param tokenB The second token address.
     * @return token0 The token address that is smaller.
     * @return token1 The token address that is larger.
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");

        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        require(token0 != address(0), "UniswapV2Library: ZERO_ADDRESS");
    }

    /**
     * @dev Calculates the CREATE2 address for a pair without making any external calls.
     * @param factory The factory contract address.
     * @param tokenA The first token address.
     * @param tokenB The second token address.
     * @return pair The pair address.
     */
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
                        )
                    )
                )
            )
        );
    }

    /**
     * @dev Fetches and sorts the reserves for a pair.
     * @param factory The factory contract address.
     * @param tokenA The first token address.
     * @param tokenB The second token address.
     * @return reserveA The reserve of tokenA.
     * @return reserveB The reserve of tokenB.
     */
    function getReserves(address factory, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @dev Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset.
     * @param amountA The amount of the first asset.
     * @param reserveA The reserve of the first asset.
     * @param reserveB The reserve of the second asset.
     * @return amountB The equivalent amount of the second asset.
     */
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        require(amountA > 0, "UniswapV2Library: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");

        amountB = (amountA * reserveB) / reserveA;
    }

    /**
     * @dev Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset.
     * @param amountIn The input amount of the first asset.
     * @param reserveIn The reserve of the first asset.
     * @param reserveOut The reserve of the second asset.
     * @return amountOut The maximum output amount of the second asset.
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /**
     * @dev Given an output amount of an asset and pair reserves, returns a required input amount of the other asset.
     * @param amountOut The output amount of the first asset.
     * @param reserveIn The reserve of the first asset.
     * @param reserveOut The reserve of the second asset.
     * @return amountIn The required input amount of the second asset.
     */
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");

        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    /**
     * @dev Performs chained getAmountOut calculations on any number of pairs.
     * @param factory The factory contract address.
     * @param amountIn The input amount of the first asset.
     * @param path The path of pairs to swap along.
     * @return amounts The output amounts of the other assets.
     */
    function getAmountsOut(address factory, uint256 amountIn, address[] memory path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @dev Performs chained getAmountIn calculations on any number of pairs.
     * @param factory The factory contract address.
     * @param amountOut The output amount of the first asset.
     * @param path The path of pairs to swap along.
     * @return amounts The required input amounts of the other assets.
     */
    function getAmountsIn(address factory, uint256 amountOut, address[] memory path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");

        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}
