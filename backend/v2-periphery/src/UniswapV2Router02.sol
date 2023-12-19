// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { IUniswapV2Factory } from "../../v2-core/src/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "../../v2-core/src/interfaces/IUniswapV2Pair.sol";
import { TransferHelper } from "../../solidity-lib/src/libraries/TransferHelper.sol";
import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";
import { UniswapV2Library } from "./libraries/UniswapV2Library.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IWETH } from "./interfaces/IWETH.sol";

/**
 * @title UniswapV2Router02
 * @dev This contract is for adding and removing liquidity, and performing swaps on Uniswap V2.
 */
contract UniswapV2Router02 is IUniswapV2Router02 {
    /**
     * @dev The factory contract address.
     */

    address public immutable override factory;
    /**
     * @dev The WETH contract address.
     */
    address public immutable override WETH;

    /**
     * @dev Modifier to make a function callable only when the deadline has not passed.
     * @param deadline Timestamp after which the transaction will revert.
     */
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");

        _;
    }

    /**
     * @dev Sets the values for {factory} and {WETH}.
     * @param _factory The address of the factory contract.
     * @param _WETH The address of the WETH contract.
     */
    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    /**
     * @dev Fallback function that only allows ETH transfers from the WETH contract.
     */
    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    /**
     * @dev Adds liquidity to a token pair.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param amountADesired The desired amount of the first token to add as liquidity.
     * @param amountBDesired The desired amount of the second token to add as liquidity.
     * @param amountAMin The minimum amount of the first token to add as liquidity.
     * @param amountBMin The minimum amount of the second token to add as liquidity.
     * @return amountA The actual amount of the first token added as liquidity.
     * @return amountB The actual amount of the second token added as liquidity.
     */
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }

        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);

            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "UniswapV2Router: INSUFFICIENT_B_AMOUNT");

                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);

                assert(amountAOptimal <= amountADesired);

                require(amountAOptimal >= amountAMin, "UniswapV2Router: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    /**
     * @dev Adds liquidity to a token pair.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param amountADesired The desired amount of the first token to add as liquidity.
     * @param amountBDesired The desired amount of the second token to add as liquidity.
     * @param amountAMin The minimum amount of the first token to add as liquidity.
     * @param amountBMin The minimum amount of the second token to add as liquidity.
     * @param to The address to receive the liquidity tokens.
     * @param deadline The time after which this transaction will revert.
     * @return amountA The actual amount of the first token added as liquidity.
     * @return amountB The actual amount of the second token added as liquidity.
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
    ) external virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);

        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);

        liquidity = IUniswapV2Pair(pair).mint(to);
    }

    /**
     * @dev Adds liquidity to a token pair, where one of the tokens is WETH.
     * @param token The address of the token (not WETH).
     * @param amountTokenDesired The desired amount of the token to add as liquidity.
     * @param amountTokenMin The minimum amount of the token to add as liquidity.
     * @param amountETHMin The minimum amount of ETH to add as liquidity.
     * @param to The address to receive the liquidity tokens.
     * @param deadline The time after which this transaction will revert.
     * @return amountToken The actual amount of the token added as liquidity.
     * @return amountETH The actual amount of ETH added as liquidity.
     * @return liquidity The amount of liquidity tokens minted.
     */
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity)
    {
        (amountToken, amountETH) =
            _addLiquidity(token, WETH, amountTokenDesired, msg.value, amountTokenMin, amountETHMin);
        address pair = UniswapV2Library.pairFor(factory, token, WETH);

        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);

        IWETH(WETH).deposit{ value: amountETH }();

        assert(IWETH(WETH).transfer(pair, amountETH));

        liquidity = IUniswapV2Pair(pair).mint(to);

        // refund dust eth, if any
        if (msg.value > amountETH) {
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
        }
    }

    // **** REMOVE LIQUIDITY ****
    /**
     * @dev Removes liquidity from a token pair.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param liquidity The amount of liquidity tokens to burn.
     * @param amountAMin The minimum amount of the first token to receive.
     * @param amountBMin The minimum amount of the second token to receive.
     * @param to The address to receive the tokens.
     * @param deadline The time after which this transaction will revert.
     * @return amountA The actual amount of the first token received.
     * @return amountB The actual amount of the second token received.
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);

        IUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair

        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(pair).burn(to);
        (address token0,) = UniswapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);

        require(amountA >= amountAMin, "UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "UniswapV2Router: INSUFFICIENT_B_AMOUNT");
    }

    /**
     * @dev Removes liquidity from a token pair, where one of the tokens is WETH.
     * @param token The address of the token (not WETH).
     * @param liquidity The amount of liquidity tokens to burn.
     * @param amountTokenMin The minimum amount of the token to receive.
     * @param amountETHMin The minimum amount of ETH to receive.
     * @param to The address to receive the tokens.
     * @param deadline The time after which this transaction will revert.
     * @return amountToken The actual amount of the token received.
     * @return amountETH The actual amount of ETH received.
     */
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) =
            removeLiquidity(token, WETH, liquidity, amountTokenMin, amountETHMin, address(this), deadline);

        TransferHelper.safeTransfer(token, to, amountToken);

        IWETH(WETH).withdraw(amountETH);

        TransferHelper.safeTransferETH(to, amountETH);
    }

    /**
     * @dev Allows a user to remove liquidity from a Uniswap pair with a permit.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param liquidity The amount of liquidity to remove.
     * @param amountAMin The minimum amount of tokenA to receive.
     * @param amountBMin The minimum amount of tokenB to receive.
     * @param to The address to send the removed liquidity to.
     * @param deadline The time by which the transaction must be included to be valid.
     * @param approveMax Whether to approve the maximum possible amount of liquidity to remove.
     * @param v The recovery id of the ECDSA signature.
     * @param r The first output of the ECDSA signature.
     * @param s The second output of the ECDSA signature.
     * @return amountA The amount of tokenA received.
     * @return amountB The amount of tokenB received.
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
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? type(uint256).max : liquidity;

        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);

        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    /**
     * @dev Allows a user to remove liquidity from a Uniswap pair with a permit, where one of the tokens is WETH.
     * @param token The address of the token in the pair (not WETH).
     * @param liquidity The amount of liquidity to remove.
     * @param amountTokenMin The minimum amount of the token to receive.
     * @param amountETHMin The minimum amount of ETH to receive.
     * @param to The address to send the removed liquidity to.
     * @param deadline The time by which the transaction must be included to be valid.
     * @param approveMax Whether to approve the maximum possible amount of liquidity to remove.
     * @param v The recovery id of the ECDSA signature.
     * @param r The first output of the ECDSA signature.
     * @param s The second output of the ECDSA signature.
     * @return amountToken The amount of the token received.
     * @return amountETH The amount of ETH received.
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
    ) external virtual override returns (uint256 amountToken, uint256 amountETH) {
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        uint256 value = approveMax ? type(uint256).max : liquidity;

        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);

        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    /**
     * @dev Allows a user to remove liquidity from a Uniswap pair, where one of the tokens is WETH and the other is a fee-on-transfer token.
     * @param token The address of the fee-on-transfer token in the pair (not WETH).
     * @param liquidity The amount of liquidity to remove.
     * @param amountTokenMin The minimum amount of the token to receive.
     * @param amountETHMin The minimum amount of ETH to receive.
     * @param to The address to send the removed liquidity to.
     * @param deadline The time by which the transaction must be included to be valid.
     * @return amountETH The amount of ETH received.
     */
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountETH) {
        (, amountETH) = removeLiquidity(token, WETH, liquidity, amountTokenMin, amountETHMin, address(this), deadline);

        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));

        IWETH(WETH).withdraw(amountETH);

        TransferHelper.safeTransferETH(to, amountETH);
    }

    /**
     * @dev Allows a user to remove liquidity from a Uniswap pair with a permit, where one of the tokens is WETH and the other is a fee-on-transfer token.
     * @param token The address of the fee-on-transfer token in the pair (not WETH).
     * @param liquidity The amount of liquidity to remove.
     * @param amountTokenMin The minimum amount of the token to receive.
     * @param amountETHMin The minimum amount of ETH to receive.
     * @param to The address to send the removed liquidity to.
     * @param deadline The time by which the transaction must be included to be valid.
     * @param approveMax Whether to approve the maximum possible amount of liquidity to remove.
     * @param v The recovery id of the ECDSA signature.
     * @param r The first output of the ECDSA signature.
     * @param s The second output of the ECDSA signature.
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
    ) external virtual override returns (uint256 amountETH) {
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        uint256 value = approveMax ? type(uint256).max : liquidity;

        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);

        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    /**
     * @dev Swaps an amount of one token for another along a path of pairs.
     * @param amounts The amounts of the tokens to swap.
     * @param path The path of pairs to swap along.
     * @param _to The address to send the output tokens to.
     */
    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;

            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to);
        }
    }

    /**
     * @dev Swaps an exact amount of input tokens for as many output tokens as possible, along the route determined by the path.
     * @param amountIn The amount of input tokens to send.
     * @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
     * @param path The path of pairs to swap along.
     * @param to The address to send the output tokens to.
     * @param deadline The time by which the transaction must be included to be valid.
     * @return amounts The input token amounts.
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);

        require(amounts[amounts.length - 1] >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );

        _swap(amounts, path, to);
    }

    /**
     * @dev Swaps as few input tokens as possible for an exact amount of output tokens, along the route determined by the path.
     * @param amountOut The amount of output tokens to receive.
     * @param amountInMax The maximum amount of input tokens that can be sent.
     * @param path The path of pairs to swap along.
     * @param to The address to send the output tokens to.
     * @param deadline The time by which the transaction must be included to be valid.
     * @return amounts The input token amounts.
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);

        require(amounts[0] <= amountInMax, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );

        _swap(amounts, path, to);
    }

    /**
     * @dev Swaps an exact amount of ETH for as many output tokens as possible, along the route determined by the path.
     * @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
     * @param path The path of pairs to swap along.
     * @param to The address to send the output tokens to.
     * @param deadline The time by which the transaction must be included to be valid.
     * @return amounts The input token amounts.
     */
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WETH, "UniswapV2Router: INVALID_PATH");

        amounts = UniswapV2Library.getAmountsOut(factory, msg.value, path);

        require(amounts[amounts.length - 1] >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        IWETH(WETH).deposit{ value: amounts[0] }();

        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));

        _swap(amounts, path, to);
    }

    /**
     * @dev Swaps as few input tokens as possible for an exact amount of ETH, along the route determined by the path.
     * @param amountOut The amount of ETH to receive.
     * @param amountInMax The maximum amount of input tokens that can be sent.
     * @param path The path of pairs to swap along.
     * @param to The address to send the ETH to.
     * @param deadline The time by which the transaction must be included to be valid.
     * @return amounts The input token amounts.
     */
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH");

        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);

        require(amounts[0] <= amountInMax, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );

        _swap(amounts, path, address(this));

        IWETH(WETH).withdraw(amounts[amounts.length - 1]);

        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    /**
     * @dev Swaps an exact amount of input tokens for as many ETH as possible, along the route determined by the path.
     * @param amountIn The amount of input tokens to send.
     * @param amountOutMin The minimum amount of ETH that must be received for the transaction not to revert.
     * @param path The path of pairs to swap along.
     * @param to The address to send the ETH to.
     * @param deadline The time by which the transaction must be included to be valid.
     * @return amounts The input token amounts.
     */
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH");

        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);

        require(amounts[amounts.length - 1] >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );

        _swap(amounts, path, address(this));

        IWETH(WETH).withdraw(amounts[amounts.length - 1]);

        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    /**
     * @dev Swaps an exact amount of ETH for as many output tokens as possible, along the route determined by the path.
     * @param amountOut The amount of output tokens to receive.
     * @param path The path of pairs to swap along.
     * @param to The address to send the output tokens to.
     * @param deadline The time by which the transaction must be included to be valid.
     * @return amounts The input token amounts.
     */
    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WETH, "UniswapV2Router: INVALID_PATH");

        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);

        require(amounts[0] <= msg.value, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");

        IWETH(WETH).deposit{ value: amounts[0] }();

        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));

        _swap(amounts, path, to);

        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    /**
     * @dev Swaps an amount of one token for another along a path of pairs, where the input tokens are fee-on-transfer tokens.
     * @param path The path of pairs to swap along.
     * @param _to The address to send the output tokens to.
     */
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;

            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }

            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;

            pair.swap(amount0Out, amount1Out, to);
        }
    }

    /**
     * @dev Swaps an exact amount of tokens for another token, supporting fee-on-transfer tokens.
     * @param amountIn The amount of input tokens to use.
     * @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
     * @param path The path of pairs to swap along.
     * @param to The address to send the output tokens to.
     * @param deadline The time by which the transaction must be included to be valid.
     */
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );

        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);

        _swapSupportingFeeOnTransferTokens(path, to);

        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    /**
     * @dev Swaps an exact amount of ETH for tokens, supporting fee-on-transfer tokens.
     * @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
     * @param path The path of pairs to swap along.
     * @param to The address to send the output tokens to.
     * @param deadline The time by which the transaction must be included to be valid.
     */
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == WETH, "UniswapV2Router: INVALID_PATH");

        uint256 amountIn = msg.value;

        IWETH(WETH).deposit{ value: amountIn }();

        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn));

        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);

        _swapSupportingFeeOnTransferTokens(path, to);

        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    /**
     * @dev Swaps an exact amount of tokens for ETH, supporting fee-on-transfer tokens.
     * @param amountIn The amount of input tokens to use.
     * @param amountOutMin The minimum amount of output ETH that must be received for the transaction not to revert.
     * @param path The path of pairs to swap along.
     * @param to The address to send the output ETH to.
     * @param deadline The time by which the transaction must be included to be valid.
     */
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH");

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );

        _swapSupportingFeeOnTransferTokens(path, address(this));

        uint256 amountOut = IERC20(WETH).balanceOf(address(this));

        require(amountOut >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        IWETH(WETH).withdraw(amountOut);

        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    /**
     * @dev Returns the amount of output tokens that can be received for the given input amount.
     * @param amountA The amount of the input token.
     * @param reserveA The liquidity reserve for the input token.
     * @param reserveB The liquidity reserve for the output token.
     * @return amountB The amount of output tokens that can be received.
     */
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        public
        pure
        virtual
        override
        returns (uint256 amountB)
    {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    /**
     * @dev Returns the amount of output tokens that can be received for the given input amount.
     * @param amountIn The amount of the input token.
     * @param reserveIn The liquidity reserve for the input token.
     * @param reserveOut The liquidity reserve for the output token.
     * @return amountOut The amount of output tokens that can be received.
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        virtual
        override
        returns (uint256 amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /**
     * @dev Returns the amount of input tokens needed to receive the given output amount.
     * @param amountOut The amount of the output token.
     * @param reserveIn The liquidity reserve for the input token.
     * @param reserveOut The liquidity reserve for the output token.
     * @return amountIn The amount of input tokens needed.
     */
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    /**
     * @dev Returns the amounts of output tokens that can be received for the given input amount along a path of pairs.
     * @param amountIn The amount of the input token.
     * @param path The path of pairs to swap along.
     * @return amounts The amounts of output tokens that can be received.
     */
    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    /**
     * @dev Returns the amounts of output tokens that can be received for the given input amount along a path of pairs.
     * @param amountIn The amount of the input token.
     * @param path The path of pairs to swap along.
     * @param pair The pair address.
     * @return amounts The amounts of output tokens that can be received.
     */
    function getAmountsOutByPair(uint256 amountIn, address[] memory path, address pair)
        public
        virtual
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsOutByPair(pair, amountIn, path);
    }

    /**
     * @dev Returns the amounts of input tokens needed to receive the given output amount along a path of pairs.
     * @param amountOut The amount of the output token.
     * @param path The path of pairs to swap along.
     * @return amounts The amounts of input tokens needed.
     */
    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }
}
