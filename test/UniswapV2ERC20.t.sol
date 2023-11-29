// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ERC20 } from "../src/contracts/test/ERC20.sol";
import { UniswapV2ERC20 } from "../src/contracts/UniswapV2ERC20.sol";

contract UniswapV2ERC20Test is Test {
    ERC20 internal uniswapV2ERC20;

    uint256 internal constant TOTAL_SUPPLY = 100 * 10 ** 18;
    uint256 internal constant SIGNER_PRIVATE_KEY = 0xabc123;
    uint256 internal immutable NONCE;

    address internal immutable SIGNER;


    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor() {
        uniswapV2ERC20 = new ERC20(TOTAL_SUPPLY);
        SIGNER = vm.addr(SIGNER_PRIVATE_KEY);
        NONCE = UniswapV2ERC20(uniswapV2ERC20).nonces(SIGNER);
    }

    function testApprove(address spender, uint256 value) public {
        vm.expectEmit(address(uniswapV2ERC20));

        emit Approval(address(this), spender, value);

        uniswapV2ERC20.approve(spender, value);
    }

    function testTransfer(address to, uint256 value) public {
        vm.assume(value <= TOTAL_SUPPLY);
        vm.assume(to != address(this));

        uint256 senderBalanceBefore = uniswapV2ERC20.balanceOf(address(this));
        uint256 recipientBalanceBefore = uniswapV2ERC20.balanceOf(to);

        vm.expectEmit(address(uniswapV2ERC20));

        emit Transfer(address(this), to, value);

        uniswapV2ERC20.transfer(to, value);

        uint256 senderBalanceAfter = uniswapV2ERC20.balanceOf(address(this));
        uint256 recipientBalanceAfter = uniswapV2ERC20.balanceOf(to);

        assertEq(senderBalanceBefore - value, senderBalanceAfter);
        assertEq(recipientBalanceBefore + value, recipientBalanceAfter);
    }

    function testTransferFrom(address to, uint256 value) public {
        vm.assume(value <= TOTAL_SUPPLY);
        vm.assume(to != address(this));

        uint256 senderBalanceBefore = uniswapV2ERC20.balanceOf(address(this));
        uint256 recipientBalanceBefore = uniswapV2ERC20.balanceOf(to);

        uniswapV2ERC20.approve(address(this), value);

        vm.expectEmit(address(uniswapV2ERC20));

        emit Transfer(address(this), to, value);

        uniswapV2ERC20.transferFrom(address(this), to, value);

        uint256 senderBalanceAfter = uniswapV2ERC20.balanceOf(address(this));
        uint256 recipientBalanceAfter = uniswapV2ERC20.balanceOf(to);

        assertEq(senderBalanceBefore - value, senderBalanceAfter);
        assertEq(recipientBalanceBefore + value, recipientBalanceAfter);
    }

    function testRevertTransferFromWithoutAllowance(address to, uint256 value) public {
        vm.assume(value > 0);
        vm.assume(value <= TOTAL_SUPPLY);

        vm.expectRevert();

        uniswapV2ERC20.transferFrom(address(this), to, value);
    }

    function testPermit(address spender, uint256 value, uint256 deadline) public {
        vm.assume(deadline >= block.timestamp);

        vm.startPrank(SIGNER);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                uniswapV2ERC20.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(uniswapV2ERC20.PERMIT_TYPEHASH(), SIGNER, spender, value, NONCE, deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        address verifiedSigner = ecrecover(digest, v, r, s);

        assertEq(SIGNER, verifiedSigner, "Signer's address does not match");

        vm.expectEmit(address(uniswapV2ERC20));

        emit Approval(SIGNER, spender, value);

        uniswapV2ERC20.permit(SIGNER, spender, value, deadline, v, r, s);

        vm.stopPrank();
    }

    function testRevertPermitPassedDeadline(address spender, uint256 value, uint256 deadline) public {
        vm.assume(deadline < block.timestamp);

        vm.startPrank(SIGNER);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                uniswapV2ERC20.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(uniswapV2ERC20.PERMIT_TYPEHASH(), SIGNER, spender, value, NONCE, deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        address verifiedSigner = ecrecover(digest, v, r, s);

        assertEq(SIGNER, verifiedSigner, "Signer's address does not match");

        vm.expectRevert("UniswapV2: EXPIRED");

        uniswapV2ERC20.permit(SIGNER, spender, value, deadline, v, r, s);

        vm.stopPrank();
    }

    function testRevertPermitInvalidSignature(address spender, uint256 value, uint256 deadline) public {
        vm.assume(deadline >= block.timestamp);

        uint256 incorrectPrivateKey = 0x123abc;

        vm.startPrank(SIGNER);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                uniswapV2ERC20.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(uniswapV2ERC20.PERMIT_TYPEHASH(), SIGNER, spender, value, NONCE, deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(incorrectPrivateKey, digest);

        vm.expectRevert("UniswapV2: INVALID_SIGNATURE");

        uniswapV2ERC20.permit(SIGNER, spender, value, deadline, v, r, s);

        vm.stopPrank();
    }
}