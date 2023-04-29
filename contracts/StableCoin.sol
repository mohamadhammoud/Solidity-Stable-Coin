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
    uint16 INITIAL_COLLATERAL_RATIO_PERCENTAGE = 10; // 10%

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
        int256 dificitOrSurplusBalanceInUsd = _getDificitOrSurplusBalanceInUsd();
        require(dificitOrSurplusBalanceInUsd >= 0, "STC: Deficit status");

        _burn(msg.sender, burnStableCoinAmount);

        uint256 refundingEth = burnStableCoinAmount / oracle.getPrice();
        uint256 fee = _getFee(refundingEth);
        uint256 remainingEth = refundingEth - fee;

        (bool success, ) = msg.sender.call{value: remainingEth}("");
        require(success, "STC: refund Eth transfer failed");
    }

    function depositCollateral() external payable {
        int256 dificitOrSurplusBalanceInUsd = _getDificitOrSurplusBalanceInUsd();

        if (dificitOrSurplusBalanceInUsd > 0) {
            uint256 surplusInUsd = uint256(dificitOrSurplusBalanceInUsd);

            uint256 dpcPriceInUsd = _getDPCPriceinUsd(surplusInUsd);

            uint256 depositorCoinAmount = ((msg.value * dpcPriceInUsd) /
                oracle.getPrice());

            _depositorCoin.mint(msg.sender, depositorCoinAmount);
            return;
        }

        uint256 dificitInUsd = uint256(dificitOrSurplusBalanceInUsd * -1);
        uint256 usdInEthPrice = oracle.getPrice();

        uint256 dificitInEth = dificitInUsd / usdInEthPrice;

        uint256 requiredInitialSurplusInUsd = (dificitInUsd *
            INITIAL_COLLATERAL_RATIO_PERCENTAGE) / 100;

        uint256 requiredInitialSurplusInEth = requiredInitialSurplusInUsd /
            usdInEthPrice;

        require(
            msg.value >= dificitInEth + requiredInitialSurplusInEth,
            "STC: Initial collateral ration not met"
        );

        uint newInitialSurpusInEth = msg.value - dificitInEth;
        uint newInitialSurpusInUsd = newInitialSurpusInEth * usdInEthPrice;

        _depositorCoin = new DepositorCoin();
        uint256 mintDepositorCointAmount = newInitialSurpusInUsd;
        _depositorCoin.mint(msg.sender, mintDepositorCointAmount);
    }

    function _getFee(uint256 amount) private returns (uint256) {
        bool hasDepositors = address(_depositorCoin) != address(0) &&
            _depositorCoin.totalSupply() != 0;

        if (hasDepositors) {
            return (amount * feeRatePercentage) / PRECISION;
        }

        return 0;
    }

    function withdrawCollateral(uint256 depositorCoinAmount) external {
        require(
            _depositorCoin.balanceOf(msg.sender) > depositorCoinAmount,
            "STC: Insufficient DPC"
        );

        _depositorCoin.burn(msg.sender, depositorCoinAmount);

        int256 dificitOrSurplusInUsd = _getDificitOrSurplusBalanceInUsd();
        require(dificitOrSurplusInUsd > 0, "STC: No funds to withdraw");

        uint256 surplusInUsd = uint256(dificitOrSurplusInUsd);
        uint256 dpcPriceInUsd = _getDPCPriceinUsd(surplusInUsd);

        uint256 usdAmountToRefund = depositorCoinAmount / dpcPriceInUsd;
        uint256 ethAmountToRefund = usdAmountToRefund / oracle.getPrice();

        (bool success, ) = msg.sender.call{value: ethAmountToRefund}("");

        require(success, "STC: refund Eth transfer failed");
    }

    function _getDificitOrSurplusBalanceInUsd() private returns (int256) {
        uint256 ethBalance = address(this).balance - msg.value;

        uint256 ethBalanceInUSD = ethBalance * oracle.getPrice();

        int dificitOrSurplus = ethBalanceInUSD - totalSupply();

        return dificitOrSurplus;
    }

    function _getDPCPriceinUsd(uint256 surplusUsd) private returns (uint256) {
        return _depositorCoin.totalSupply() / surplusUsd;
    }
}
