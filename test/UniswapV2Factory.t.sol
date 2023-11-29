// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ERC20 } from "../src/test/ERC20.sol";
import { UniswapV2Factory } from "../src/UniswapV2Factory.sol";
import { UniswapV2Pair } from "../src/UniswapV2Pair.sol";

contract UniswapV2FactoryTest is Test {
    UniswapV2Factory internal uniswapV2Factory;

    uint256 internal constant TOTAL_SUPPLY = 100 * 10 ** 18;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor() {
        uniswapV2Factory = new UniswapV2Factory(address(this));
    }

    function testCreatePair(address tokenA, address tokenB) public {
        vm.assume(tokenA != tokenB);
        vm.assume(tokenA != address(0));
        vm.assume(tokenB != address(0));

        uint256 allPairsLengthBefore = uniswapV2Factory.allPairsLength();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        address pair = getPair(tokenA, tokenB);

        vm.expectEmit(true, true, true, false, address(uniswapV2Factory));

        emit PairCreated(token0, token1, pair, allPairsLengthBefore + 1);

        uniswapV2Factory.createPair(tokenA, tokenB);

        uint256 allPairsLengthAfter = uniswapV2Factory.allPairsLength();

        assertEq(allPairsLengthBefore + 1, allPairsLengthAfter);
    }

    function testRevertCreatePairIdenticalAddress() public {
        address tokenA = address(1);
        address tokenB = address(1);

        vm.expectRevert("UniswapV2: IDENTICAL_ADDRESSES");

        uniswapV2Factory.createPair(tokenA, tokenB);
    }

    function testRevertCreatePairZeroAddress(address tokenB) public {
        address tokenA = address(0);

        vm.assume(tokenA != tokenB);

        vm.expectRevert("UniswapV2: ZERO_ADDRESS");

        uniswapV2Factory.createPair(tokenA, tokenB);
    }

    function testRevertCreatePairPairExists(address tokenA, address tokenB) public {
        vm.assume(tokenA != tokenB);
        vm.assume(tokenA != address(0));
        vm.assume(tokenB != address(0));

        uint256 allPairsLengthBefore = uniswapV2Factory.allPairsLength();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        address pair = getPair(tokenA, tokenB);

        vm.expectEmit(true, true, true, false, address(uniswapV2Factory));

        emit PairCreated(token0, token1, pair, allPairsLengthBefore + 1);

        uniswapV2Factory.createPair(tokenA, tokenB);

        vm.expectRevert("UniswapV2: PAIR_EXISTS");

        uniswapV2Factory.createPair(tokenA, tokenB);
    }

    function testSetFeeTo(address newFeeTo) public {
        uniswapV2Factory.setFeeTo(newFeeTo);

        assertEq(newFeeTo, uniswapV2Factory.feeTo());
    }

    function testRevertSetFeeToForbbiden(address newFeeTo, address forbiddenSetter) public {
        vm.assume(forbiddenSetter != address(this));

        vm.prank(forbiddenSetter);

        vm.expectRevert("UniswapV2: FORBIDDEN");

        uniswapV2Factory.setFeeTo(newFeeTo);
    }

    function testSetFeeToSetter(address newFeeToSetter) public {
        uniswapV2Factory.setFeeToSetter(newFeeToSetter);

        assertEq(newFeeToSetter, uniswapV2Factory.feeToSetter());
    }

    function testRevertSetFeeToSetterForbbiden(address newFeeToSetter, address forbiddenSetter) public {
        vm.assume(forbiddenSetter != address(this));

        vm.prank(forbiddenSetter);

        vm.expectRevert("UniswapV2: FORBIDDEN");

        uniswapV2Factory.setFeeToSetter(newFeeToSetter);
    }

    function getPair(address tokenA, address tokenB) private returns (address pair) {
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
    }
}