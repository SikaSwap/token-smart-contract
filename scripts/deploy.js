const hre = require("hardhat");
const fs = require("fs").promises;

async function main() {
  const taxAddress = "0xC4A522D25D1918387aab969aAF55cF9F707E6b82" // Replace your tax wallet
  const SikaSwap = await hre.ethers.getContractFactory("SikaSwap");
  const _sikaSwap = await SikaSwap.deploy(taxAddress);
  await _sikaSwap.waitForDeployment();

  console.log("SikaSwap token deployed: ", await _sikaSwap.getAddress());
  // Wait for a minute before proceeding, to ensure everything is set up
  console.log("Waiting 1 Minute Before Starting Airdrops...");
  await new Promise(resolve => setTimeout(resolve, 60000)); // 60,000 milliseconds = 1 minute
  await run(`verify:verify`, {
    address: await _sikaSwap.getAddress(),
    constructorArguments: [taxAddress],
  });

  // Load the airdrop.json file
  const airdropData = JSON.parse(await fs.readFile("airdrop.json", "utf8"));

  // Iterate over each airdrop entry and perform the token transfer
  for (const { Name, EthereumAddress, TokensToAirdrop } of airdropData) {
    // set liquidity holder for airdrop addresses
    const setLiquidityHolder = await _sikaSwap.setLiquidityHolder(EthereumAddress, true);
    console.log("liquidity holder set for : ", Name);
    // Convert token amount to the correct format, if necessary
    const tokens = hre.ethers.parseUnits(TokensToAirdrop, 18);

    // Perform the token transfer
    const transfertx = await _sikaSwap.transfer(EthereumAddress, tokens);
    await transfertx.wait(1);
    console.log(`${hre.ethers.formatEther(tokens)} tokens transferred to ${EthereumAddress} named ${Name}`);
  }
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
