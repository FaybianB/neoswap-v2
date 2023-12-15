// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

/**
 * @title IWETH
 * @dev Interface for WETH (Wrapped Ether)
 */
interface IWETH {
    /**
     * @dev Deposits ETH and mints WETH
     */
    function deposit() external payable;

    /**
     * @dev Transfers WETH from caller to another address
     * @param to The address to transfer the WETH to
     * @param value The amount of WETH to transfer
     * @return A boolean value indicating whether the operation succeeded
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Withdraws ETH from contract, burning WETH
     * @param value The amount of WETH to burn
     */
    function withdraw(uint256 value) external;
}
