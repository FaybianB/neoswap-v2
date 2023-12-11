// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IUniswapV2ERC20
 * @dev Interface for Uniswap V2 ERC20 tokens
 */
interface IUniswapV2ERC20 is IERC20 {
    /**
     * @dev Returns the name of the token
     */
    function name() external pure returns (string memory);

    /**
     * @dev Returns the symbol of the token
     */
    function symbol() external pure returns (string memory);

    /**
     * @dev Returns the number of decimals the token uses
     */
    function decimals() external pure returns (uint8);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for `permit`, as defined by EIP-712
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /**
     * @dev Returns the EIP-712 typehash used for `permit` signature verification
     */
    function PERMIT_TYPEHASH() external pure returns (bytes32);

    /**
     * @dev Returns the number of permits (`owner`) has signed, according to EIP-2612
     * @param owner The address of the account owning tokens
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Allows `spender` to spend `value` tokens on behalf of `owner`
     * @param owner The address of the account owning tokens
     * @param spender The address of the account spending tokens
     * @param value The number of tokens that are being approved for transfer
     * @param deadline The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}