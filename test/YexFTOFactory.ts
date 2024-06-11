import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("YexFTOFactory", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployYexFTOFactory() {
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const ONE_GWEI = 1_000_000_000;
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();
    const YexFTOFactory = await ethers.getContractFactory("YexFTOFactory");
    const yexFTOFactory = await YexFTOFactory.deploy();

    return { yexFTOFactory, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Owner should be match", async function () {
      const { yexFTOFactory, owner } = await loadFixture(deployYexFTOFactory);
      expect(await yexFTOFactory.owner()).to.equal(owner.address);
    });
  });

  describe("RaisedToken", function () {
    it("Only owner can add raisedToken", async function () {
      const { yexFTOFactory, owner, otherAccount } = await loadFixture(
        deployYexFTOFactory
      );

      const raisedToken = "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2";

      await expect(
        yexFTOFactory.connect(otherAccount).addRaisedToken(raisedToken)
      ).to.be.rejectedWith("Ownable: caller is not the owner");

      await yexFTOFactory.connect(owner).addRaisedToken(raisedToken);
    });
  });

  describe("CreateFTO", function () {
    it("Only whiteList caller can create", async function () {
      const { yexFTOFactory, owner, otherAccount } = await loadFixture(
        deployYexFTOFactory
      );
      const raisedToken = "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2";
      await yexFTOFactory.connect(owner).addRaisedToken(raisedToken);

      const otherToken = "0x5d116b0032188519e62858dFd3b7917ccEcad170";
      const poolHandler = "0xBF5BB6e4189877bA03168035a56CBC452f59c0d2";
      await expect(
        yexFTOFactory
          .connect(otherAccount)
          .createFTO(
            otherAccount.address,
            raisedToken,
            "SECOND",
            "SC2",
            1000000000000000000000n,
            poolHandler,
            1787798
          )
      ).to.be.revertedWith("WhiteList: only whiteList can create");
    });
    it("Only raised token can create", async function () {
      const { yexFTOFactory, owner, otherAccount } = await loadFixture(
        deployYexFTOFactory
      );
      const raisedToken = "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2";
      await yexFTOFactory.connect(owner).addRaisedToken(raisedToken);
      const otherToken = "0x5d116b0032188519e62858dFd3b7917ccEcad170";
      const poolHandler = "0xBF5BB6e4189877bA03168035a56CBC452f59c0d2";

      // add whiteList
      await yexFTOFactory.connect(owner).addWhiteList(otherAccount.address);

      await expect(
        yexFTOFactory
          .connect(otherAccount)
          .createFTO(
            otherAccount.address,
            otherToken,
            "SECOND",
            "SC2",
            1000000000000000000000n,
            poolHandler,
            1787798
          )
      ).to.be.rejectedWith("YexFTOFactory: NOT_ALLOWED_BASE_TOKEN");
    });
    it("batchAddWhiteList", async function () {
      const { yexFTOFactory, owner, otherAccount } = await loadFixture(
        deployYexFTOFactory
      );

      // await yexFTOFactory.removeWhiteList(otherAccount.address);

      const raisedToken = "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2";
      await yexFTOFactory.connect(owner).addRaisedToken(raisedToken);

      const otherToken = "0x5d116b0032188519e62858dFd3b7917ccEcad170";
      const poolHandler = "0xBF5BB6e4189877bA03168035a56CBC452f59c0d2";

      await yexFTOFactory
        .connect(owner)
        .batchAddWhiteList([otherAccount.address, owner.address]);

      await yexFTOFactory
        .connect(otherAccount)
        .createFTO(
          otherAccount.address,
          raisedToken,
          "First",
          "FT",
          2000000000000000000000n,
          poolHandler,
          1787798
        );
      await yexFTOFactory
        .connect(owner)
        .createFTO(
          owner.address,
          raisedToken,
          "SECOND",
          "SC",
          1000000000000000000000n,
          poolHandler,
          1787798
        );
    });
  });
});
