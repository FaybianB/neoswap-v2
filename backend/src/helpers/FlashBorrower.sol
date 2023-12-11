// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Pair } from "../interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "../interfaces/IUniswapV2Factory.sol";
import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import { IERC3156FlashLender } from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import { UniswapV2Pair } from "../UniswapV2Pair.sol";

/**
 * @title FlashBorrower
 * @dev Contract that allows for flash loans using the ERC3156 standard.
 */
contract FlashBorrower is IERC3156FlashBorrower {
    // The flash lender contract
    IERC3156FlashLender private _lender;

    bool private _enableReturn = true;

    // Event emitted when a loan is taken
    event LoanTaken(address indexed lender, address indexed token, uint256 amountBorrowed);

    /**
     * @dev Constructor that sets the lender contract.
     * @param lender_ The address of the lender contract.
     */
    constructor(IERC3156FlashLender lender_) {
        _lender = lender_;
    }

    /**
     * @dev Function that is called when a flash loan is executed.
     * @param initiator The address initiating the flash loan.
     * @param token The address of the token being loaned.
     * @param amount The amount of tokens being loaned.
     * @param fee The fee for the flash loan.
     * @param data Additional data for the flash loan.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan".
     */
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        require(msg.sender == address(_lender), "FlashBorrower: Untrusted lender");
        require(initiator == address(this), "FlashBorrower: Untrusted loan initiator");

        emit LoanTaken(msg.sender, token, amount);

        return _enableReturn ? keccak256("ERC3156FlashBorrower.onFlashLoan") : bytes32(0);
    }

    /**
     * @dev Function that initiates a flash loan.
     * @param token The address of the token to be loaned.
     * @param amount The amount of tokens to be loaned.
     */
    function flashBorrow(address token, uint256 amount) external {
        uint256 _allowance = IERC20(token).allowance(address(this), address(_lender));
        uint256 _fee = _lender.flashFee(token, amount);
        uint256 _repayment = amount + _fee;

        IERC20(token).approve(address(_lender), _allowance + _repayment);

        _lender.flashLoan(this, token, amount, "");
    }

    function setEnableReturn(bool enable) external {
        _enableReturn = enable;
    }
}