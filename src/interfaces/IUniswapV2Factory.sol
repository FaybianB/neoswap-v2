// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title IUniswapV2Factory
 * @dev Interface for Uniswap V2 Factory
 */
interface IUniswapV2Factory {
    /**
     * @dev Emitted when a new pair is created
     * @param token0 The address of the first token in the pair
     * @param token1 The address of the second token in the pair
     * @param pair The address of the pair
     * @param data Any additional data that might be needed
     */
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 data);

    /**
     * @dev Returns the fee to address
     * @return address The address of the fee recipient
     */
    function feeTo() external view returns (address);

    /**
     * @dev Returns the fee to setter address
     * @return address The address of the fee setter
     */
    function feeToSetter() external view returns (address);

    /**
     * @dev Returns the pair address for a given pair of tokens
     * @param tokenA The address of the first token
     * @param tokenB The address of the second token
     * @return pair The address of the pair
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair);

    /**
     * @dev Returns the pair address for a given index
     * @param index The index of the pair
     * @return pair The address of the pair
     */
    function allPairs(uint256 index) external view returns (address pair);

    /**
     * @dev Returns the total number of pairs
     * @return uint256 The total number of pairs
     */
    function allPairsLength() external view returns (uint256);

    /**
     * @dev Creates a new pair
     * @param tokenA The address of the first token
     * @param tokenB The address of the second token
     * @return pair The address of the newly created pair
     */
    function createPair(address tokenA, address tokenB) external returns (address pair);

    /**
     * @dev Sets the fee to a new address
     * @param newFeeAddress The new fee address
     */
    function setFeeTo(address newFeeAddress) external;

    /**
     * @dev Sets the fee setter to a new address
     * @param newFeeSetterAddress The new fee setter address
     */
    function setFeeToSetter(address newFeeSetterAddress) external;
}