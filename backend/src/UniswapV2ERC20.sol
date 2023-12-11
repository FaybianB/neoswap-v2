// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { IUniswapV2ERC20 } from "./interfaces/IUniswapV2ERC20.sol";

/**
 * @title UniswapV2ERC20
 * @dev Implementation of the UniswapV2ERC20
 */
contract UniswapV2ERC20 is IUniswapV2ERC20 {
    string public constant name = "Uniswap V2";
    string public constant symbol = "UNI-V2";

    uint8 public constant decimals = 18;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    // Allowance of tokens from one account to another
    mapping(address => mapping(address => uint256)) public allowance;

    // EIP-712 Domain Separator
    bytes32 public immutable DOMAIN_SEPARATOR;
    // EIP-712 Typehash for the permit function
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    // Nonces for permit function
    mapping(address => uint256) public nonces;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @dev Transfer `value` tokens from `msg.sender` to `to`
     * @param to The address to transfer to.
     * @param value The amount of tokens to be transferred.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        _transfer(msg.sender, to, value);

        return true;
    }

    /**
     * @dev Transfer `value` tokens from `from` to `to`
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount of tokens to be transferred.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        // Check if the allowance is not maxed out
        if (allowance[from][msg.sender] != type(uint256).max) {
            // Subtract the transferred value from the allowance
            allowance[from][msg.sender] = allowance[from][msg.sender] - value;
        }

        _transfer(from, to, value);

        return true;
    }

    /**
     * @dev Approve `spender` to transfer `value` tokens on behalf of `msg.sender`
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);

        return true;
    }

    /**
     * @dev Allows `spender` to spend `value` tokens on behalf of `owner`
     * @param owner The address which owns the funds.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param deadline Time after which this permission to spend is no longer valid
     * @param v ECDSA signature parameter v.
     * @param r ECDSA signature parameter r.
     * @param s ECDSA signature parameter s.
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        require(deadline >= block.timestamp, "UniswapV2: EXPIRED");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);

        require(recoveredAddress != address(0) && recoveredAddress == owner, "UniswapV2: INVALID_SIGNATURE");

        _approve(owner, spender, value);
    }

    /**
     * @dev Creates `value` tokens and assigns them to `to`, increasing the total supply.
     * @param to The address to assign the tokens to.
     * @param value The amount of tokens to be created.
     */
    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply + value;
        balanceOf[to] = balanceOf[to] + value;

        emit Transfer(address(0), to, value);
    }

    /**
     * @dev Destroys `value` tokens from `from`, reducing the total supply.
     * @param from The address to remove the tokens from.
     * @param value The amount of tokens to be removed.
     */
    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from] - value;
        totalSupply = totalSupply - value;

        emit Transfer(from, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     * @param owner The address which owns the funds.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be allowed to spend.
     */
    function _approve(address owner, address spender, uint256 value) private {
        allowance[owner][spender] = value;

        emit Approval(owner, spender, value);
    }

    /**
     * @dev Moves `value` tokens from `from` to `to`.
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount of tokens to be transferred.
     */
    function _transfer(address from, address to, uint256 value) private {
        balanceOf[from] = balanceOf[from] - value;
        balanceOf[to] = balanceOf[to] + value;

        emit Transfer(from, to, value);
    }
}
