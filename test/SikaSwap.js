const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { constants } = require("ethers");
const { ethers, UniswapV2Deployer } = require("hardhat");

function eth(amount) {
  return ethers.utils.parseEther(amount.toString());
}

describe("SikaSwap", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deploySikaSwapFixture() {
    const [deployer, taxAddress, target] = await ethers.getSigners();
    console.log(deployer.address);
    console.log(taxAddress.address);
    console.log(target.address);
    // deploy the uniswap v2 protocol
    const { factory, router, weth9 } = await UniswapV2Deployer.deploy(deployer);
    // deploy token
    const SikaSwap = await ethers.getContractFactory("SikaSwap", deployer);
    const sikaSwap = await SikaSwap.deploy(
      taxAddress.address,
      factory.address,
      weth9.address
    );
    await sikaSwap.waitForDeployment();
    // get our pair
    const pair = new ethers.Contract(
      await sikaSwap.pair(),
      UniswapV2Deployer.Interface.IUniswapV2Pair.abi
    );
    // approve the spending
    await weth9.approve(router.address, eth(1000));
    await sikaSwap.approve(router.address, eth(1000));
    // add liquidity
    await router.addLiquidityETH(
      sikaSwap.address,
      eth(500),
      eth(500),
      eth(10),
      deployer.address,
      ethers.constants.MaxUint256,
      { value: eth(10) }
    );
    console.log(sikaSwap.address);
    return { sikaSwap, deployer, taxAddress, target, factory, router, weth9, pair };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { sikaSwap, deployer } = await loadFixture(deploySikaSwapFixture);
      console.log(deployer.address, await sikaSwap.owner());
      expect(await sikaSwap.owner()).to.equal(deployer.address);
    });
  });
  describe("transfer", function () {
    it("Should transfer", async function () {
      const { sikaSwap, deployer, target } = await loadFixture(deploySikaSwapFixture);
      await sikaSwap.transfer(target.address, eth(100));
      expect(await sikaSwap.balanceOf(target.address)).to.equal(eth(100));
    });
    it("Should tax on buy", async function () {
      const { sikaSwap, deployer, target, router, weth9, taxAddress, pair } = await loadFixture(deploySikaSwapFixture);
      // await router.swapExactETHForTokens(
      //   0,
      //   [weth9.address, sikaSwap.address],
      //   target.address,
      //   ethers.constants.MaxUint256,
      //   { value: eth(1) }
      // );
      // expect(await sikaSwap.balanceOf(target.address)).to.equal(eth(0.99));
      // expect(await sikaSwap.balanceOf(deployer.address)).to.equal(eth(0.01));
      await expect(router.swapETHForExactTokens((
        eth(100),
        [weth9.address, sikaSwap.address],
        deployer.address,
        ethers.constants.MaxUint256,
        { value: eth(1000) }
      )).to.changeTokenBalances(sikaSwap, [deployer, taxAddress, pair], [eth(95), eth(5), eth(100).mul(-1)]));
    });
  })
});
