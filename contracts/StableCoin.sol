// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {DepositorCoin} from "./DepositorCoin/DepositorCoin.sol";

contract StableCoin is ERC20 {
    DepositorCoin _depositorCoin;

    uint16 ETH_PRICE_PER_USD = 2000;

    uint16 PRECISION = 1e4;
    uint16 feeRatePercentage; // 2 decimals

    constructor(name, symbol, feeRatePercentage_) ERC20(name, symbol) {
        owner = msg.sender;

        feeRatePercentage = feeRatePercentage_;
    }

    function mint() external payable {
        uint256 fee = _getFee(msg.value);
        uint256 remainingEth = msg.value - fee;

        uint256 mintStableCointAmount = remainingEth * ETH_PRICE_PER_USD;
        _mint(msg.sender, mintStableCointAmount);
    }

    function burn(uint256 burnStableCoinAmount) external {
        _burn(msg.sender, burnStableCoinAmount);

        uint256 refundingEth = burnStableCoinAmount / ETH_PRICE_PER_USD;

        uint256 fee = _getFee(refundingEth);

        uint256 remainingEth = refundingEth - fee;

        (bool success, ) = msg.sender.call{value: remainingEth}("");

        requier(success, "STC: refund Eth transfer failed");
    }

    function _getFee(uint256 amount) private {
        bool hasDepositors = address(_depositorCoin) != address(0) &&
            _depositorCoin.totalSupply() != 0;

        if (hasDepositors) {
            return (amount * feePercentage) / PRECISION;
        }

        return 0;
    }
}
