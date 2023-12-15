// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

/**
 * @title IUniswapV2Pair
 * @dev Interface for Uniswap V2 Pair
 */
interface IUniswapV2Pair {
    /**
     * @dev Emitted when `amount0` and `amount1` are minted to `sender`
     * @param sender The address of the account minting the tokens
     * @param amount0 The amount of token0 minted
     * @param amount1 The amount of token1 minted
     */
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

    /**
     * @dev Emitted when `amount0` and `amount1` are burned from `sender` to `to`
     * @param sender The address of the account burning the tokens
     * @param amount0 The amount of token0 burned
     * @param amount1 The amount of token1 burned
     * @param to The address of the account receiving the tokens
     */
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);

    /**
     * @dev Emitted when a swap occurs
     * @param sender The address of the account initiating the swap
     * @param amount0In The amount of token0 input
     * @param amount1In The amount of token1 input
     * @param amount0Out The amount of token0 output
     * @param amount1Out The amount of token1 output
     * @param to The address of the account receiving the output
     */
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    /**
     * @dev Emitted when reserves are synced
     * @param reserve0 The reserve of token0
     * @param reserve1 The reserve of token1
     */
    event Sync(uint112 reserve0, uint112 reserve1);

    /**
     * @dev Returns the minimum liquidity
     * @return The minimum liquidity
     */
    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    /**
     * @dev Returns the factory address
     * @return The factory address
     */
    function factory() external view returns (address);

    /**
     * @dev Returns the address of token0
     * @return The address of token0
     */
    function token0() external view returns (address);

    /**
     * @dev Returns the address of token1
     * @return The address of token1
     */
    function token1() external view returns (address);

    /**
     * @dev Returns the reserves and the last block timestamp
     * @return reserve0 The reserve of token0
     * @return reserve1 The reserve of token1
     * @return blockTimestampLast The last block timestamp
     */
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    /**
     * @dev Returns the last cumulative price of token0
     * @return The last cumulative price of token0
     */
    function price0CumulativeLast() external view returns (uint256);

    /**
     * @dev Returns the last cumulative price of token1
     * @return The last cumulative price of token1
     */
    function price1CumulativeLast() external view returns (uint256);

    /**
     * @dev Returns the last k value
     * @return The last k value
     */
    function kLast() external view returns (uint256);

    /**
     * @dev Mints liquidity to `to`
     * @param to The address of the account receiving the liquidity
     * @return liquidity The amount of liquidity minted
     */
    function mint(address to) external returns (uint256 liquidity);

    /**
     * @dev Burns liquidity from `to`
     * @param to The address of the account burning the liquidity
     * @return amount0 The amount of token0 burned
     * @return amount1 The amount of token1 burned
     */
    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    /**
     * @dev Swaps `amount0Out` and `amount1Out` to `to`
     * @param amount0Out The amount of token0 output
     * @param amount1Out The amount of token1 output
     * @param to The address of the account receiving the output
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;

    /**
     * @dev Skims `to`
     * @param to The address of the account to skim
     */
    function skim(address to) external;

    /**
     * @dev Syncs the reserves
     */
    function sync() external;

    /**
     * @dev Initializes the pair with `token0` and `token1`
     * @param token0 The address of token0
     * @param token1 The address of token1
     */
    function initialize(address token0, address token1) external;
}