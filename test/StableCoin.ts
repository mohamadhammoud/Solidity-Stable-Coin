import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract } from "ethers";
import { depositorCoin } from "../typechain-types/contracts";

const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("StableCoin", function () {
  let user1: SignerWithAddress, user2: SignerWithAddress;
  let StableCoin: Contract, ethUsdOracle: Contract;

  const feeRatePercentage = ethers.utils.parseUnits("3", 2); // 3%
  const ethUsdPrice = 4000;

  beforeEach(async function () {
    [user1, user2] = await ethers.getSigners();

    const OracleFactory = await ethers.getContractFactory("Oracle", user1);
    ethUsdOracle = await OracleFactory.deploy(ethUsdPrice);

    StableCoin = await (
      await ethers.getContractFactory("StableCoin", user1)
    ).deploy("StableCoin", "STC", feeRatePercentage, ethUsdOracle.address);
  });

  it("Should set fee rate percentage", async function () {
    expect(await StableCoin.feeRatePercentage()).to.equal(feeRatePercentage);
  });

  it("Should allow minting", async function () {
    const ethAmount = 1;

    const expectedMintAmount = ethAmount * ethUsdPrice;

    await StableCoin.mint({
      value: ethers.utils.parseUnits(ethAmount.toString(), 18),
    });

    expect(await StableCoin.balanceOf(user1.address)).to.equal(
      ethers.utils.parseUnits("4000", 18) // 1 ether * 4000, no fees yet since there is no depositors
    );
  });

  describe("With minted tokens", function () {
    let mintAmount: number;

    beforeEach(async function () {
      const ethAmount = 1;

      mintAmount = ethAmount * ethUsdPrice;

      await StableCoin.mint({
        value: ethers.utils.parseUnits(ethAmount.toString(), 18),
      });
    });

    it("Should allow burning", async function () {
      const remainingStableCoinAmount = 100;

      await StableCoin.burn(
        ethers.utils.parseUnits(
          (mintAmount - remainingStableCoinAmount).toString(),
          18
        )
      );

      expect(await StableCoin.totalSupply()).to.equal(
        ethers.utils.parseUnits(remainingStableCoinAmount.toString(), 18)
      );
    });

    it("Should revert allow burning", async function () {
      const burnAmount = 2 * ethUsdPrice;

      await expect(
        StableCoin.burn(ethers.utils.parseUnits(burnAmount.toString(), 18))
      ).to.be.revertedWith("ERC20: burn amount exceeds balance");
    });

    describe("with deposit collateral", async function () {
      this.beforeEach(
        "Should generate depositor token after depositing collateral",
        async function () {
          const stableCoinCollateralAmount = ethers.utils.parseUnits("1", 18);

          expect(await StableCoin.getDepositorCoin()).to.equal(
            ethers.constants.AddressZero
          );

          await expect(
            StableCoin.depositCollateral({
              value: stableCoinCollateralAmount,
            })
          ).not.to.be.reverted;

          expect(await StableCoin.getDepositorCoin()).to.not.equal(
            ethers.constants.AddressZero
          );

          const DepositorCoinFactory = await ethers.getContractFactory(
            "DepositorCoin"
          );

          const depositorCoinAddress = await StableCoin.getDepositorCoin();

          const depositorCoinContract = await DepositorCoinFactory.attach(
            depositorCoinAddress
          );

          const balance = await depositorCoinContract.balanceOf(user1.address);

          expect(balance).to.equal(
            ethers.utils.parseUnits(mintAmount.toString(), 18)
          );
        }
      );

      it("Should revert if we want to burn in dificit status", async function () {
        // eth drop by half
        await ethUsdOracle.setPrice(ethUsdPrice / 4);

        await expect(
          StableCoin.burn(ethers.utils.parseUnits(mintAmount.toString(), 18))
        ).to.be.revertedWith("STC: Deficit status");
      });

      it("Should revert if we want to burn more than the deposited balance", async function () {
        // eth drop by half
        await ethUsdOracle.setPrice(ethUsdPrice / 4);

        await expect(
          StableCoin.withdrawCollateral(
            ethers.utils.parseUnits((mintAmount + 10).toString(), 18)
          )
        ).to.be.revertedWith("STC: Insufficient DPC");
      });

      it("Should revert if we want to withdraw in dificit status", async function () {
        // eth drop by half
        await ethUsdOracle.setPrice(ethUsdPrice / 4);

        await expect(
          StableCoin.withdrawCollateral(
            ethers.utils.parseUnits(mintAmount.toString(), 18)
          )
        ).to.be.revertedWith("STC: No funds to withdraw");
      });
    });
  });
});
