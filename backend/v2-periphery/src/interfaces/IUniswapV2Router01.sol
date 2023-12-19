// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.23;

/**
 * @title IUniswapV2Router01
 * @dev This interface defines the necessary methods for interacting with Uniswap V2 Router.
 */
interface IUniswapV2Router01 {
    /**
     * @dev Returns the address of the Uniswap V2 factory contract.
     * @return The address of the Uniswap V2 factory contract.
     */
    function factory() external view returns (address);

    /**
     * @dev Returns the address of the Wrapped Ether (WETH) contract.
     * @return The address of the Wrapped Ether (WETH) contract.
     */
    function WETH() external view returns (address);

    /**
     * @dev Adds liquidity to a token pair on Uniswap.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param amountADesired The maximum amount of tokenA to add to the pool.
     * @param amountBDesired The maximum amount of tokenB to add to the pool.
     * @param amountAMin The minimum amount of tokenA to add to the pool.
     * @param amountBMin The minimum amount of tokenB to add to the pool.
     * @param to The address to receive the liquidity tokens.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @return amountA The actual amount of tokenA added to the pool.
     * @return amountB The actual amount of tokenB added to the pool.
     * @return liquidity The amount of liquidity tokens minted.
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /**
     * @dev Adds liquidity to a token pair on Uniswap, where one of the tokens is WETH.
     * @param token The address of the token (not WETH).
     * @param amountTokenDesired The maximum amount of token to add to the pool.
     * @param amountTokenMin The minimum amount of token to add to the pool.
     * @param amountETHMin The minimum amount of WETH to add to the pool.
     * @param to The address to receive the liquidity tokens.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @return amountToken The actual amount of token added to the pool.
     * @return amountETH The actual amount of WETH added to the pool.
     * @return liquidity The amount of liquidity tokens minted.
     */
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    /**
     * @dev Removes liquidity from a token pair on Uniswap.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param liquidity The amount of liquidity tokens to burn.
     * @param amountAMin The minimum amount of tokenA to receive.
     * @param amountBMin The minimum amount of tokenB to receive.
     * @param to The address to receive the withdrawn tokens.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @return amountA The actual amount of tokenA received.
     * @return amountB The actual amount of tokenB received.
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    /**
     * @dev Removes liquidity from a token pair on Uniswap, where one of the tokens is WETH.
     * @param token The address of the token (not WETH).
     * @param liquidity The amount of liquidity tokens to burn.
     * @param amountTokenMin The minimum amount of token to receive.
     * @param amountETHMin The minimum amount of WETH to receive.
     * @param to The address to receive the withdrawn tokens.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @return amountToken The actual amount of token received.
     * @return amountETH The actual amount of WETH received.
     */
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    /**
     * @dev Removes liquidity from a token pair on Uniswap with permit.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param liquidity The amount of liquidity tokens to burn.
     * @param amountAMin The minimum amount of tokenA to receive.
     * @param amountBMin The minimum amount of tokenB to receive.
     * @param to The address to receive the withdrawn tokens.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @param approveMax Whether to approve the maximum possible amount.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return amountA The actual amount of tokenA received.
     * @return amountB The actual amount of tokenB received.
     */
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    /**
     * @dev Removes liquidity from a token pair on Uniswap, where one of the tokens is WETH, with permit.
     * @param token The address of the token (not WETH).
     * @param liquidity The amount of liquidity tokens to burn.
     * @param amountTokenMin The minimum amount of token to receive.
     * @param amountETHMin The minimum amount of WETH to receive.
     * @param to The address to receive the withdrawn tokens.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @param approveMax Whether to approve the maximum possible amount.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return amountToken The actual amount of token received.
     * @return amountETH The actual amount of WETH received.
     */
    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    /**
     * @dev Swaps an exact amount of input tokens for as many output tokens as possible.
     * @param amountIn The amount of input tokens to send.
     * @param amountOutMin The minimum amount of output tokens to receive.
     * @param path An array of token addresses. The path[i] and path[i + 1] represent a pair of tokens to be swapped.
     * @param to The address to receive the output tokens.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @return amounts The amount of each token involved in the swaps.
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /**
     * @dev Swaps an exact amount of input tokens for as many output tokens as possible.
     * @param amountIn The amount of input tokens to send.
     * @param amountOutMin The minimum amount of output tokens to receive.
     * @param path An array of token addresses. The path[i] and path[i + 1] represent a pair of tokens to be swapped.
     * @param to The address to receive the output tokens.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @return amounts The amount of each token involved in the swaps.
     */
     function swapExactTokensForTokensByPair(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        address pair
    ) external returns (uint256[] memory amounts);

    /**
     * @dev Swaps as few input tokens as possible for an exact amount of output tokens.
     * @param amountOut The amount of output tokens to receive.
     * @param amountInMax The maximum amount of input tokens to send.
     * @param path An array of token addresses. The path[i] and path[i + 1] represent a pair of tokens to be swapped.
     * @param to The address to receive the output tokens.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @return amounts The amount of each token involved in the swaps.
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /**
     * @dev Swaps an exact amount of ETH for as many output tokens as possible.
     * @param amountOutMin The minimum amount of output tokens to receive.
     * @param path An array of token addresses. The path[i] and path[i + 1] represent a pair of tokens to be swapped.
     * @param to The address to receive the output tokens.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @return amounts The amount of each token involved in the swaps.
     */
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);

    /**
     * @dev Swaps as few input tokens as possible for an exact amount of ETH.
     * @param amountOut The amount of ETH to receive.
     * @param amountInMax The maximum amount of input tokens to send.
     * @param path An array of token addresses. The path[i] and path[i + 1] represent a pair of tokens to be swapped.
     * @param to The address to receive the ETH.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @return amounts The amount of each token involved in the swaps.
     */
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /**
     * @dev Swaps an exact amount of input tokens for as many ETH as possible.
     * @param amountIn The amount of input tokens to send.
     * @param amountOutMin The minimum amount of ETH to receive.
     * @param path An array of token addresses. The path[i] and path[i + 1] represent a pair of tokens to be swapped.
     * @param to The address to receive the ETH.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @return amounts The amount of each token involved in the swaps.
     */
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /**
     * @dev Swaps an exact amount of ETH for as many output tokens as possible.
     * @param amountOut The amount of output tokens to receive.
     * @param path An array of token addresses. The path[i] and path[i + 1] represent a pair of tokens to be swapped.
     * @param to The address to receive the output tokens.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @return amounts The amount of each token involved in the swaps.
     */
    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);

    /**
     * @dev Provides the quote for the given parameters.
     * @param amountA The amount of the first token.
     * @param reserveA The reserve of the first token.
     * @param reserveB The reserve of the second token.
     * @return amountB The amount of the second token.
     */
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);

    /**
     * @dev Returns the amount of output tokens that can be received for the given input amount.
     * @param amountIn The amount of input tokens.
     * @param reserveIn The reserve of the input token.
     * @param reserveOut The reserve of the output token.
     * @return amountOut The amount of output tokens.
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        returns (uint256 amountOut);

    /**
     * @dev Returns the amount of input tokens required to receive the given output amount.
     * @param amountOut The amount of output tokens.
     * @param reserveIn The reserve of the input token.
     * @param reserveOut The reserve of the output token.
     * @return amountIn The amount of input tokens.
     */
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountIn);

    /**
     * @dev Returns the amount of each token involved in the swaps for the given input amount.
     * @param amountIn The amount of input tokens.
     * @param path An array of token addresses. The path[i] and path[i + 1] represent a pair of tokens to be swapped.
     * @return amounts The amount of each token involved in the swaps.
     */
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        returns (uint256[] memory amounts);

    /**
     * @dev Returns the amount of each token involved in the swaps for the given output amount.
     * @param amountOut The amount of output tokens.
     * @param path An array of token addresses. The path[i] and path[i + 1] represent a pair of tokens to be swapped.
     * @return amounts The amount of each token involved in the swaps.
     */
    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        returns (uint256[] memory amounts);
}
