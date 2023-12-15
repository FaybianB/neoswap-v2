// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { IUniswapV2Factory } from "./interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair, UniswapV2Pair } from "./UniswapV2Pair.sol";

/**
 * @title UniswapV2Factory
 * @dev A contract for creating and managing Uniswap V2 pairs
 */
contract UniswapV2Factory is IUniswapV2Factory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;

    address[] public allPairs;

    /**
     * @dev Initializes the UniswapV2Factory contract
     * @param _feeToSetter The address that can set the feeTo address
     */
    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    /**
     * @dev Returns the number of allPairs
     * @return The length of allPairs
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /**
     * @dev Creates a new Uniswap V2 pair
     * @param tokenA The address of token A
     * @param tokenB The address of token B
     * @return pair The address of the created pair
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // Check if tokenA and tokenB are not the same
        require(tokenA != tokenB, "UniswapV2: IDENTICAL_ADDRESSES");

        // Sort the tokens in ascending order
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        // Check if token0 is not the zero address
        require(token0 != address(0), "UniswapV2: ZERO_ADDRESS");
        // Check if the pair does not already exist
        require(getPair[token0][token1] == address(0), "UniswapV2: PAIR_EXISTS");

        // Get the bytecode of the UniswapV2Pair contract
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        // Generate a salt for the pair creation
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        // Create the pair contract using create2
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        // Initialize the pair contract with the tokens
        IUniswapV2Pair(pair).initialize(token0, token1);

        // Set the pair address in the getPair mapping for both token0 and token1
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;

        // Add the pair address to the allPairs array
        allPairs.push(pair);

        // Emit an event for the creation of the pair
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @dev Sets the feeTo address
     * @param _feeTo The address to set as feeTo
     */
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");

        feeTo = _feeTo;
    }

    /**
     * @dev Sets the feeToSetter address
     * @param _feeToSetter The address to set as feeToSetter
     */
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");

        feeToSetter = _feeToSetter;
    }
}
