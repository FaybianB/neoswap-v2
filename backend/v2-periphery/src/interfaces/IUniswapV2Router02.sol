// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.23;

import { IUniswapV2Router01 } from "./IUniswapV2Router01.sol";

/**
 * @title IUniswapV2Router02
 * @dev This interface inherits from IUniswapV2Router01 and includes additional methods for interacting with Uniswap V2 Router.
 */
interface IUniswapV2Router02 is IUniswapV2Router01 {
    /**
     * @dev Removes liquidity for ETH and a token, supporting fee on transfer tokens.
     * @param token The address of the token.
     * @param liquidity The amount of liquidity to remove.
     * @param amountTokenMin The minimum amount of token to receive.
     * @param amountETHMin The minimum amount of ETH to receive.
     * @param to The address to receive the ETH and token.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @return amountETH The amount of ETH received.
     */
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    /**
     * @dev Removes liquidity for ETH and a token with permit, supporting fee on transfer tokens.
     * @param token The address of the token.
     * @param liquidity The amount of liquidity to remove.
     * @param amountTokenMin The minimum amount of token to receive.
     * @param amountETHMin The minimum amount of ETH to receive.
     * @param to The address to receive the ETH and token.
     * @param deadline The time by which the transaction must be included to be considered valid.
     * @param approveMax Whether to approve the maximum amount.
     * @param v The recovery id of the signature.
     * @param r The r value of the signature.
     * @param s The s value of the signature.
     * @return amountETH The amount of ETH received.
     */
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
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
    ) external returns (uint256 amountETH);

    /**
     * @dev Swaps an exact amount of tokens for another token, supporting fee on transfer tokens.
     * @param amountIn The amount of input tokens to send.
     * @param amountOutMin The minimum amount of output tokens to receive.
     * @param path An array of token addresses. The path[i] and path[i + 1] represent a pair of tokens to be swapped.
     * @param to The address to receive the output tokens.
     * @param deadline The time by which the transaction must be included to be considered valid.
     */
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    /**
     * @dev Swaps an exact amount of ETH for tokens, supporting fee on transfer tokens.
     * @param amountOutMin The minimum amount of output tokens to receive.
     * @param path An array of token addresses. The path[i] and path[i + 1] represent a pair of tokens to be swapped.
     * @param to The address to receive the output tokens.
     * @param deadline The time by which the transaction must be included to be considered valid.
     */
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    /**
     * @dev Swaps an exact amount of tokens for ETH, supporting fee on transfer tokens.
     * @param amountIn The amount of input tokens to send.
     * @param amountOutMin The minimum amount of ETH to receive.
     * @param path An array of token addresses. The path[i] and path[i + 1] represent a pair of tokens to be swapped.
     * @param to The address to receive the ETH.
     * @param deadline The time by which the transaction must be included to be considered valid.
     */
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}
