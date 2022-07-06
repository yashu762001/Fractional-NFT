const { assert, expect } = require("chai");
const { networks, deployments, getNamedAccounts, ethers } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");

if (developmentChains.includes(network.name)) {
  describe("Fractional NFT Tests", async function () {
    let basicNft, fractionalNft, deployer, player1, accounts;
    const FEES = ethers.utils.parseEther("0.001");
    const TOKEN_ID = 0;
    const NFT_PRICE = ethers.utils.parseEther("10");

    beforeEach(async () => {
      accounts = await ethers.getSigners();
      player1 = accounts[1];

      deployer = (await getNamedAccounts()).deployer;
      await deployments.fixture(["all"]);
      basicNft = await ethers.getContract("BasicNFT", deployer);
      fractionalNft = await ethers.getContract("FractionalNFT", deployer);

      await basicNft.mintNFT();
    });

    it("Making NFT Public", async function () {
      const INITIAL_CONTRACT_BALANCE = await fractionalNft.provider.getBalance(
        fractionalNft.address
      );
      await fractionalNft.makeNFTPublic(
        basicNft.address,
        TOKEN_ID,
        1000,
        NFT_PRICE,
        400,
        { value: FEES }
      );
      const FINAL_CONTRACT_BALANCE = await fractionalNft.provider.getBalance(
        fractionalNft.address
      );

      assert.equal(
        INITIAL_CONTRACT_BALANCE.add(FEES).toString(),
        FINAL_CONTRACT_BALANCE.toString()
      );
      const remainingShares = await fractionalNft.getNFTRemainingShares(
        basicNft.address,
        TOKEN_ID
      );
      assert.equal(remainingShares.toString(), "600");

      let sharePrice = await fractionalNft.getNFTSharePrice(
        basicNft.address,
        TOKEN_ID
      );
      sharePrice = sharePrice.toString();
      assert.equal((sharePrice * 1000).toString(), NFT_PRICE.toString());

      const feesCollected = await fractionalNft.getFeesCollected();
      assert.equal(feesCollected.toString(), FEES.toString());

      const ownerShares = await fractionalNft.getSharesOfOwner(
        basicNft.address,
        TOKEN_ID
      );
      assert.equal(ownerShares.toString(), "400");

      const totalShares = await fractionalNft.getNFTTotalShares(
        basicNft.address,
        TOKEN_ID
      );
      assert.equal(totalShares.toString(), "1000");
    });

    it("Buy Shares in NFT", async function () {
      await fractionalNft.makeNFTPublic(
        basicNft.address,
        TOKEN_ID,
        1000,
        NFT_PRICE,
        400,
        { value: FEES }
      );
      const INITIAL_CONTRACT_BALANCE = await fractionalNft.provider.getBalance(
        fractionalNft.address
      );
      const sharePrice = await fractionalNft.getNFTSharePrice(
        basicNft.address,
        TOKEN_ID
      );
      let toPay = (
        (sharePrice.toString() * 20) /
        1000000000000000000
      ).toString();
      toPay = ethers.utils.parseEther(toPay);

      const fractionalNFTInvestor = fractionalNft.connect(player1);
      await fractionalNFTInvestor.buySharesInNFT(
        basicNft.address,
        TOKEN_ID,
        20,
        {
          value: toPay,
        }
      );

      const FINAL_CONTRACT_BALANCE = await fractionalNft.provider.getBalance(
        fractionalNft.address
      );

      assert.equal(
        INITIAL_CONTRACT_BALANCE.add(toPay).toString(),
        FINAL_CONTRACT_BALANCE
      );

      const remainingShares = await fractionalNft.getNFTRemainingShares(
        basicNft.address,
        TOKEN_ID
      );
      assert.equal(remainingShares.toString(), "580");

      const usersShare = await fractionalNft.getUsersShareInNFT(
        basicNft.address,
        TOKEN_ID,
        player1.address
      );
      assert.equal(usersShare.toString(), "20");

      const amountCollected = await fractionalNft.getAmountCollectedForNFT(
        basicNft.address,
        TOKEN_ID
      );
      assert.equal(amountCollected.toString(), toPay.toString());
    });

    it("Stock Split", async function () {
      await fractionalNft.makeNFTPublic(
        basicNft.address,
        TOKEN_ID,
        1000,
        NFT_PRICE,
        400,
        { value: FEES }
      );
      const totalSharesInitially = await fractionalNft.getNFTTotalShares(
        basicNft.address,
        TOKEN_ID
      );
      const fractionalNFTInvestor = fractionalNft.connect(player1);

      const sharePrice = await fractionalNft.getNFTSharePrice(
        basicNft.address,
        TOKEN_ID
      );
      let toPay = (
        (sharePrice.toString() * 20) /
        1000000000000000000
      ).toString();

      toPay = ethers.utils.parseEther(toPay);

      await fractionalNFTInvestor.buySharesInNFT(
        basicNft.address,
        TOKEN_ID,
        20,
        { value: toPay }
      );
      const INITIAL_CONTRACT_BALANCE = await fractionalNft.provider.getBalance(
        fractionalNft.address
      );
      let initialRemainingShares = await fractionalNft.getNFTRemainingShares(
        basicNft.address,
        TOKEN_ID
      );
      initialRemainingShares = initialRemainingShares.toString();

      let inititalShareHolderShares = await fractionalNft.getUsersShareInNFT(
        basicNft.address,
        TOKEN_ID,
        player1.address
      );
      inititalShareHolderShares = inititalShareHolderShares.toString();

      let initialSharesOfOwner = await fractionalNft.getSharesOfOwner(
        basicNft.address,
        TOKEN_ID
      );
      initialSharesOfOwner = initialSharesOfOwner.toString();

      await fractionalNft.stockSplit(basicNft.address, TOKEN_ID, 2, {
        value: FEES,
      });
      const FINAL_CONTRACT_BALANCE = await fractionalNft.provider.getBalance(
        fractionalNft.address
      );

      assert.equal(
        INITIAL_CONTRACT_BALANCE.add(FEES).toString(),
        FINAL_CONTRACT_BALANCE.toString()
      );

      const finalTotalShares = await fractionalNft.getNFTTotalShares(
        basicNft.address,
        TOKEN_ID
      );
      assert.equal(
        (totalSharesInitially.toString() * 2).toString(),
        finalTotalShares.toString()
      );

      const finalRemainingShares = await fractionalNft.getNFTRemainingShares(
        basicNft.address,
        TOKEN_ID
      );

      assert.equal(
        (initialRemainingShares * 2).toString(),
        finalRemainingShares.toString()
      );

      const finalShareHolderShares = await fractionalNft.getUsersShareInNFT(
        basicNft.address,
        TOKEN_ID,
        player1.address
      );

      assert.equal(
        (inititalShareHolderShares * 2).toString(),
        finalShareHolderShares.toString()
      );

      const finalSharePrice = await fractionalNft.getNFTSharePrice(
        basicNft.address,
        TOKEN_ID
      );

      assert.equal(
        (sharePrice.toString() / 2).toString(),
        finalSharePrice.toString()
      );

      const finalSharesOfOwner = await fractionalNft.getSharesOfOwner(
        basicNft.address,
        TOKEN_ID
      );

      assert.equal(
        (initialSharesOfOwner * 2).toString(),
        finalSharesOfOwner.toString()
      );
    });
  });
}
