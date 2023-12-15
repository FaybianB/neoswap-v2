pragma solidity 0.8.23;

import { UniswapV2ERC20 } from "../UniswapV2ERC20.sol";

contract ERC20Mock is UniswapV2ERC20 {
    bool allowTransfer = true;
    bool allowTransferFrom = true;

    constructor(uint256 _totalSupply) {
        _mint(msg.sender, _totalSupply);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (!allowTransfer) {
            return false;
        }

        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (!allowTransferFrom) {
            return false;
        }

        return super.transferFrom(from, to, value);
    }

    function setAllowTransfer(bool allow) external {
        allowTransfer = allow;
    }

    function setAllowTransferFrom(bool allow) external {
        allowTransferFrom = allow;
    }
}
