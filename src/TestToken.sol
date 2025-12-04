// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "solmate/src/tokens/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("TestToken", "TEST", 18) {
        _mint(msg.sender, 1_000_000e18); // mint 1M to deployer
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
