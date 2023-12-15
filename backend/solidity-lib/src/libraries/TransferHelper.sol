// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.23;

/**
 * @title TransferHelper
 * @dev Library for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
 */
library TransferHelper {
    /**
     * @dev Approves the transfer of tokens from the caller's address to another address
     * @param token The address of the token contract
     * @param to The address to approve the transfer to
     * @param value The amount of tokens to approve for transfer
     */
    function safeApprove(address token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));

        require(
            success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper::safeApprove: approve failed"
        );
    }

    /**
     * @dev Transfers tokens from the caller's address to another address
     * @param token The address of the token contract
     * @param to The address to transfer the tokens to
     * @param value The amount of tokens to transfer
     */
    function safeTransfer(address token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));

        require(
            success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper::safeTransfer: transfer failed"
        );
    }

    /**
     * @dev Transfers tokens from one address to another
     * @param token The address of the token contract
     * @param from The address to transfer the tokens from
     * @param to The address to transfer the tokens to
     * @param value The amount of tokens to transfer
     */
    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper::transferFrom: transferFrom failed"
        );
    }

    /**
     * @dev Transfers ETH from the caller's address to another address
     * @param to The address to transfer the ETH to
     * @param value The amount of ETH to transfer
     */
    function safeTransferETH(address to, uint256 value) internal {
        (bool success,) = to.call{ value: value }(new bytes(0));

        require(success, "TransferHelper::safeTransferETH: ETH transfer failed");
    }
}
