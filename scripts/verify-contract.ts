import * as hre from "hardhat";

export async function verify(
  contractAddress: string,
  contractFile: any,
  args: any[]
) {
  console.log("Verifying contract...");
  try {
    await hre.run("verify:verify", {
      address: contractAddress,
      contract: contractFile,
      constructorArguments: args,
    });
  } catch (e: any) {
    if (e.message.toLowerCase().includes("already verified")) {
      console.log("Already verified!");
    } else {
      console.error(e);
    }
  }
}
