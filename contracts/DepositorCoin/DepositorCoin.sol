// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DepositorCoin is ERC20 {
    address owner;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        owner = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        require(owner == msg.sender, "DPC: Only Owner can mint");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(owner == msg.sender, "DPC: Only Owner can burn");
        _burn(from, amount);
    }
}
