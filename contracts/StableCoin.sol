// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {DepositorCoin} from "./DepositorCoin/DepositorCoin.sol";

import {Oracle} from "./Oracle/Oracle.sol";

contract StableCoin is ERC20 {
    DepositorCoin _depositorCoin;
    Oracle oracle;

    uint16 PRECISION = 1e4;
    uint16 feeRatePercentage; // 2 decimals

    constructor(
        string memory name,
        string memory symbol,
        uint16 feeRatePercentage_,
        Oracle oracle_
    ) ERC20(name, symbol) {
        feeRatePercentage = feeRatePercentage_;

        oracle = oracle_;
    }

    function mint() external payable {
        uint256 fee = _getFee(msg.value);
        uint256 remainingEth = msg.value - fee;

        uint256 mintStableCointAmount = remainingEth * oracle.getPrice();
        _mint(msg.sender, mintStableCointAmount);
    }

    function burn(uint256 burnStableCoinAmount) external {
        _burn(msg.sender, burnStableCoinAmount);

        uint256 refundingEth = burnStableCoinAmount / oracle.getPrice();

        uint256 fee = _getFee(refundingEth);

        uint256 remainingEth = refundingEth - fee;

        (bool success, ) = msg.sender.call{value: remainingEth}("");

        require(success, "STC: refund Eth transfer failed");
    }

    function _getFee(uint256 amount) private returns (uint256) {
        bool hasDepositors = address(_depositorCoin) != address(0) &&
            _depositorCoin.totalSupply() != 0;

        if (hasDepositors) {
            return (amount * feeRatePercentage) / PRECISION;
        }

        return 0;
    }
}
