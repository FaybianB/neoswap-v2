// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import { IUniswapV2Pair } from "./interfaces/IUniswapV2Pair.sol";
import { UniswapV2ERC20 } from "./UniswapV2ERC20.sol";
import { UD60x18, ud60x18 } from "@prb/math/UD60x18.sol";
import { Math } from "./libraries/Math.sol";
import { IUniswapV2Factory } from "./interfaces/IUniswapV2Factory.sol";
import { UD60x18, ud60x18 } from "@prb/math/UD60x18.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import { IERC3156FlashLender } from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";

/**
 * @title UniswapV2Pair
 * @dev This contract is a Uniswap V2 pair for two tokens, implementing ERC20 and flash loan functionality.
 */
contract UniswapV2Pair is IUniswapV2Pair, UniswapV2ERC20, IERC3156FlashLender {
    using SafeERC20 for IERC20;

    // The selector for the transfer function
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    // reserve0 * reserve1, as of immediately after the most recent liquidity event
    uint256 public kLast;
    uint256 private _unlocked = 1;
    //  3 == 0.003 %.
    uint256 public constant FEE = 3;

    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    mapping(address => bool) public supportedTokens;

    /**
     * @notice Emitted when a loan is issued
     * @param borrower The address of the borrower
     * @param token The address of the token that was borrowed
     * @param amountBorrowed The amount of tokens that were borrowed
     */
    event LoanIssued(address indexed borrower, address indexed token, uint256 amountBorrowed);

    modifier lock() {
        require(_unlocked == 1, "UniswapV2: LOCKED");
        _unlocked = 0;
        _;
        _unlocked = 1;
    }

    constructor() {
        factory = msg.sender;
    }

    /**
     * @dev Loan `amount` tokens to `receiver`, and takes it back plus a `flashFee` after the callback.
     * @param receiver The contract receiving the tokens, needs to implement the `onFlashLoan(address user, uint256 amount, uint256 fee, bytes calldata)` interface.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param data A data parameter to be passed on to the `receiver` for any custom use.
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        require(supportedTokens[token], "FlashLender: Unsupported currency");

        uint256 flashFee_ = _flashFee(amount);

        require(IERC20(token).transfer(address(receiver), amount), "FlashLender: Transfer failed");

        emit LoanIssued(address(receiver), token, amount);

        require(
            receiver.onFlashLoan(msg.sender, token, amount, flashFee_, data) == CALLBACK_SUCCESS,
            "FlashLender: Callback failed"
        );
        require(
            IERC20(token).transferFrom(address(receiver), address(this), amount + flashFee_),
            "FlashLender: Repay failed"
        );

        // Update the balances
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        // Update the reserves
        _update(balance0, balance1, _reserve0, _reserve1);

        return true;
    }

    /**
     * @dev The fee to be charged for a given loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(address token, uint256 amount) external view returns (uint256) {
        require(supportedTokens[token], "FlashLender: Unsupported currency");

        return _flashFee(amount);
    }

    /**
     * @dev The amount of currency available to be lent.
     * @param token The loan currency.
     * @return The amount of `token` that can be borrowed.
     */
    function maxFlashLoan(address token) external view returns (uint256) {
        return supportedTokens[token] ? IERC20(token).balanceOf(address(this)) : 0;
    }

    /**
     * @notice Initializes the pair contract with two tokens
     * @param _token0 The address of the first token
     * @param _token1 The address of the second token
     */
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "UniswapV2: FORBIDDEN");

        // Set the tokens for the pair
        token0 = _token0;
        token1 = _token1;
        // Mark the tokens as supported
        supportedTokens[token0] = true;
        supportedTokens[token1] = true;
    }

    /**
     * @notice Mints new LP tokens to the provided address
     * @param to The address to mint LP tokens to
     * @return liquidity The amount of LP tokens minted
     */
    function mint(address to) external lock returns (uint256 liquidity) {
        // Get the current reserves of the pair
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        // Get the current balances of the pair
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        // Calculate the amount of each token that has been added
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;
        // Calculate the fee and the total supply
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply;

        // Calculate the liquidity to mint
        if (_totalSupply == 0) {
            // If there is no supply, use the geometric mean
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            // Lock the first MINIMUM_LIQUIDITY tokens forever
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            // Otherwise, use the formula to calculate the liquidity to mint
            liquidity = Math.min((amount0 * _totalSupply) / _reserve0, (amount1 * _totalSupply) / _reserve1);
        }

        // Ensure that we are minting a positive amount of liquidity
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");

        // Mint the liquidity to the target address
        _mint(to, liquidity);

        // Update the reserves
        _update(balance0, balance1, _reserve0, _reserve1);
        // If the fee is on, update kLast
        // reserve0 and reserve1 are up-to-date
        if (feeOn) kLast = uint256(reserve0) * reserve1;
        // Emit a Mint event
        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * @notice Burns LP tokens and returns the underlying assets
     * @param to The address to send the underlying assets to
     * @return amount0 The amount of the first token returned
     * @return amount1 The amount of the second token returned
     */
    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        // Get the current reserves of the pair
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        // Get the addresses of the tokens
        address _token0 = token0;
        address _token1 = token1;
        // Get the current balances of the pair
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        // Get the amount of liquidity to burn
        uint256 liquidity = balanceOf[address(this)];
        // Calculate the fee and the total supply
        bool feeOn = _mintFee(_reserve0, _reserve1);
        // Must be defined here since totalSupply can update in _mintFee
        uint256 _totalSupply = totalSupply;
        // Calculate the amount of each token to return
        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;

        // Ensure that we are burning a positive amount of liquidity
        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(address(this), liquidity);

        // Transfer the underlying assets to the target address
        IERC20(_token0).safeTransfer(to, amount0);
        IERC20(_token1).safeTransfer(to, amount1);

        // Update the balances
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        // Update the reserves
        _update(balance0, balance1, _reserve0, _reserve1);

        // If the fee is on, update kLast
        // reserve0 and reserve1 are up-to-date
        if (feeOn) kLast = uint256(reserve0) * reserve1;

        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * @notice Swaps an amount of one token for the other
     * @param amount0Out The amount of the first token to swap out
     * @param amount1Out The amount of the second token to swap out
     * @param to The address to send the swapped tokens to
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external lock {
        // Ensure that the output amounts are positive
        require(amount0Out > 0 || amount1Out > 0, "UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT");

        // Get the current reserves of the pair
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        // Ensure that there is enough liquidity for the swap
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "UniswapV2: INSUFFICIENT_LIQUIDITY");

        // Initialize the balances
        uint256 balance0;
        uint256 balance1;

        {
            // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;

            // Ensure that the target address is not a token in the pair
            require(to != _token0 && to != _token1, "UniswapV2: INVALID_TO");

            // Optimistically transfer the output tokens to the target address
            if (amount0Out > 0) {
                IERC20(_token0).safeTransfer(to, amount0Out);
            }
            if (amount1Out > 0) {
                IERC20(_token1).safeTransfer(to, amount1Out);
            }

            // Update the balances
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }

        // Calculate the input amounts
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;

        // Ensure that the input amounts are positive
        require(amount0In > 0 || amount1In > 0, "UniswapV2: INSUFFICIENT_INPUT_AMOUNT");

        {
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            // Adjust the balances for the fee
            uint256 balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
            uint256 balance1Adjusted = (balance1 * 1000) - (amount1In * 3);

            // Ensure that the invariant holds
            require(
                balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * _reserve1 * (1000 ** 2),
                "UniswapV2: K"
            );
        }

        // Update the reserves
        _update(balance0, balance1, _reserve0, _reserve1);

        // Emit a Swap event
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @notice Transfers the difference between the current balance and the reserves to the provided address
     * @param to The address to send the tokens to
     */
    function skim(address to) external lock {
        // Get the addresses of the tokens
        address _token0 = token0;
        address _token1 = token1;

        // Transfer the difference between the current balance and the reserves to the target address
        IERC20(_token0).safeTransfer(to, IERC20(_token0).balanceOf(address(this)) - reserve0);
        IERC20(_token1).safeTransfer(to, IERC20(_token1).balanceOf(address(this)) - reserve1);
    }

    /**
     * @notice Updates the reserves to the current balances
     */
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    /**
     * @notice Returns the current reserves of the pair
     * @return _reserve0 The reserve of the first token
     * @return _reserve1 The reserve of the second token
     * @return _blockTimestampLast The timestamp of the last block when reserves were updated
     */
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @notice Calculates the fee for a given loan
     * @param amount The amount of tokens lent
     * @return The amount of tokens to be charged for the loan, on top of the returned principal
     */
    function _flashFee(uint256 amount) internal pure returns (uint256) {
        return ((amount * FEE) / 997) + 1;
    }

    /**
     * @notice Updates the reserves and the cumulative prices
     * @param balance0 The current balance of the first token
     * @param balance1 The current balance of the second token
     * @param _reserve0 The current reserve of the first token
     * @param _reserve1 The current reserve of the second token
     */
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "UniswapV2: OVERFLOW");

        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;

        unchecked {
            // overflow is desired
            timeElapsed = blockTimestamp - blockTimestampLast;
        }

        // If time has elapsed since the last update and the reserves are not 0
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // Update the cumulative prices
            // * never overflows, and + overflow is desired
            unchecked {
                price0CumulativeLast +=
                    ud60x18(_reserve1)
                        .mul(ud60x18(112e18).exp2())
                        .div(ud60x18(_reserve0).mul(ud60x18(1e36)))
                        .intoUint256() *
                    timeElapsed;
                price1CumulativeLast +=
                    ud60x18(_reserve0)
                        .mul(ud60x18(112e18).exp2())
                        .div(ud60x18(_reserve1).mul(ud60x18(1e36)))
                        .intoUint256() *
                    timeElapsed;
            }
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;

        emit Sync(reserve0, reserve1);
    }

    /**
     * @notice Mints fee to the feeTo address if feeOn is true and kLast is not 0
     * @param _reserve0 The current reserve of the first token
     * @param _reserve1 The current reserve of the second token
     * @return feeOn A boolean indicating if the fee is on or not
     */
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;

        if (feeOn) {
            if (_kLast != 0) {
                // Calculate the square root of the product of the reserves
                uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                // Calculate the square root of kLast
                uint256 rootKLast = Math.sqrt(_kLast);

                if (rootK > rootKLast) {
                    // Calculate the numerator for the liquidity to mint
                    uint256 numerator = totalSupply * (rootK - rootKLast);
                    // Calculate the denominator for the liquidity to mint
                    uint256 denominator = (rootK * 5) + rootKLast;
                    // Calculate the liquidity to mint
                    uint256 liquidity = numerator / denominator;

                    // If the liquidity is greater than 0, mint the liquidity to the feeTo address
                    if (liquidity > 0) {
                        _mint(feeTo, liquidity);
                    }
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }
}