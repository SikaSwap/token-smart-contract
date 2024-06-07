const hre = require("hardhat");

async function main() {
  const SikaSwap = await hre.ethers.getContractFactory("SikaSwap");
  const _sikaSwap = await SikaSwap.deploy("0xC4A522D25D1918387aab969aAF55cF9F707E6b82");
  await _sikaSwap.waitForDeployment();

  console.log("SikaSwap token deployed: ", await _sikaSwap.getAddress());
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
