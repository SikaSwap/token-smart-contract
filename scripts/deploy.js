const hre = require("hardhat");

async function main() {
  const SikaSwap = await hre.ethers.getContractFactory("CatSwap");
  // replace with your own address
  const _sikaSwap = await SikaSwap.deploy("0x6DE3Dd401A938B16F9550C5a74F1DE4dDC5F06Ce");
  await _sikaSwap.waitForDeployment();

  console.log("CatSwap token deployed: ", await _sikaSwap.getAddress());
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
