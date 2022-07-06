// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

error FractionalNFT__NoPermissionToBuySharesForNFT();
error FractionalNFT__NFTNotmadePubliYet();

contract FractionalNFT is ERC20 {
    address contractOwner;

    constructor() ERC20("Divide and Own", "FRACTION") {
        contractOwner = msg.sender;
    }

    uint256 fees = 1e15;

    struct NFTShareInfo {
        uint256 totalShares;
        uint256 sharePrice;
    }

    mapping(address => mapping(uint256 => mapping(address => uint256)))
        public UsersShareinNFT;
    mapping(address => mapping(uint256 => address[])) public nftOwners;
    mapping(address => mapping(uint256 => uint256)) public sharesHoldedByOwner;
    mapping(address => mapping(uint256 => NFTShareInfo))
        public nftSharesAndItsPrice;
    mapping(address => mapping(uint256 => uint256)) amountCollectedForNFT;
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) alreadyEarnedRoyalty;
    mapping(address => mapping(uint256 => uint256)) nftTotalShares;
    uint256 feesCollected;

    function makeNFTPublic(
        address NFT,
        uint256 tokenId,
        uint256 shares,
        uint256 NFTPrice,
        uint256 sharesOwnerWantsToKeep
    ) public payable {
        IERC721 nft = IERC721(NFT);
        if (msg.sender != nft.ownerOf(tokenId)) {
            revert FractionalNFT__NoPermissionToBuySharesForNFT();
        }

        require(msg.value == fees, "Not Sending Enough ETH to Buy Shares");
        _mint(msg.sender, shares);
        nftSharesAndItsPrice[NFT][tokenId].totalShares =
            shares -
            sharesOwnerWantsToKeep; // Shares available for public :
        uint256 shareprice = (NFTPrice) / (shares);
        nftSharesAndItsPrice[NFT][tokenId].sharePrice = shareprice;
        feesCollected += fees;
        sharesHoldedByOwner[NFT][tokenId] = sharesOwnerWantsToKeep;
        nftTotalShares[NFT][tokenId] = shares;
    }

    function buySharesInNFT(
        address NFT,
        uint256 tokenId,
        uint256 shares
    ) public payable {
        if (nftSharesAndItsPrice[NFT][tokenId].totalShares <= 0) {
            revert FractionalNFT__NFTNotmadePubliYet();
        }

        require(
            shares <= nftSharesAndItsPrice[NFT][tokenId].totalShares,
            "You are trying to buy shares more than availability"
        );

        address ownerOfNFT = IERC721(NFT).ownerOf(tokenId);
        uint256 amountttToPay = nftSharesAndItsPrice[NFT][tokenId].sharePrice *
            shares;
        require(
            msg.value == amountttToPay,
            "Not sending enough ETH to buy shares"
        );
        _transfer(ownerOfNFT, msg.sender, shares);
        nftSharesAndItsPrice[NFT][tokenId].totalShares -= shares;
        amountCollectedForNFT[NFT][tokenId] += amountttToPay;
        UsersShareinNFT[NFT][tokenId][msg.sender] = shares;
        nftOwners[NFT][tokenId].push(msg.sender);
    }

    function withdraw(address NFT, uint256 tokenId) public {
        require(
            amountCollectedForNFT[NFT][tokenId] > 0,
            "No one bought the shares sadly or You have already withdrawn the money collected"
        );
        require(
            msg.sender == IERC721(NFT).ownerOf(tokenId),
            "Do not have the permission to withdraw"
        );
        amountCollectedForNFT[NFT][tokenId] = 0;
        (bool succ, ) = payable(msg.sender).call{
            value: amountCollectedForNFT[NFT][tokenId]
        }("");
    }

    function withdrawPublicFees() public {
        require(feesCollected > 0, "Cannot withdraw");
        require(
            msg.sender == contractOwner,
            "Do not have permission to withdraw contract's fees"
        );
        feesCollected = 0;
        (bool succ, ) = payable(contractOwner).call{value: feesCollected}("");
    }

    // n could be 2,3,4,5.... etc
    function stockSplit(
        address NFT,
        uint256 tokenId,
        uint256 n
    ) public payable {
        require(msg.value == fees, "Not Enough Fees provided to buy shares");
        require(
            msg.sender == IERC721(NFT).ownerOf(tokenId),
            "Only owner can do stock split"
        );
        uint256 totalNFTShares = nftTotalShares[NFT][tokenId];

        _mint(IERC721(NFT).ownerOf(tokenId), totalNFTShares * (n - 1));
        feesCollected += fees;
        nftSharesAndItsPrice[NFT][tokenId].totalShares =
            nftSharesAndItsPrice[NFT][tokenId].totalShares *
            n;
        nftSharesAndItsPrice[NFT][tokenId].sharePrice =
            (nftSharesAndItsPrice[NFT][tokenId].sharePrice) /
            n;
        nftTotalShares[NFT][tokenId] *= n;

        sharesHoldedByOwner[NFT][tokenId] =
            sharesHoldedByOwner[NFT][tokenId] *
            n;

        for (uint256 i = 0; i < nftOwners[NFT][tokenId].length; i++) {
            address shareHolder = nftOwners[NFT][tokenId][i];
            _transfer(
                IERC721(NFT).ownerOf(tokenId),
                shareHolder,
                UsersShareinNFT[NFT][tokenId][shareHolder] * (n - 1)
            );
            UsersShareinNFT[NFT][tokenId][shareHolder] =
                UsersShareinNFT[NFT][tokenId][shareHolder] *
                n;
        }
    }

    function updateSharePriceAfterNewListing(
        address NFT,
        uint256 tokenId,
        uint256 NFTPrice
    ) public {
        uint256 totalNFTShares = nftTotalShares[NFT][tokenId];
        nftSharesAndItsPrice[NFT][tokenId].sharePrice =
            NFTPrice /
            totalNFTShares;
    }

    // Let's decide royalty fees of 5% and out of that owner decides to distribute n% amongst the share holders:

    function earnRoyalty(
        address NFT,
        uint256 tokenId,
        uint256 NFTPrice,
        uint256 n
    ) public {
        require(
            alreadyEarnedRoyalty[NFT][tokenId][NFTPrice] == 0,
            "You have already earned royalty"
        );
        uint256 totalShares = nftTotalShares[NFT][tokenId];
        uint256 sharesHoldedByPerson = UsersShareinNFT[NFT][tokenId][
            msg.sender
        ];

        uint256 royaltyEarned = (sharesHoldedByPerson * NFTPrice * 5 * n) /
            (totalShares * 100 * 100);
        require(royaltyEarned > 0, "You do not have ownership in this NFT");
        alreadyEarnedRoyalty[NFT][tokenId][NFTPrice] = 1;
        (bool succ, ) = payable(msg.sender).call{value: royaltyEarned}("");
    }

    function getNFTSharePrice(address NFT, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return nftSharesAndItsPrice[NFT][tokenId].sharePrice;
    }

    function getNFTRemainingShares(address NFT, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return nftSharesAndItsPrice[NFT][tokenId].totalShares;
    }

    function getFeesCollected() public view returns (uint256) {
        return feesCollected;
    }

    function getSharesOfOwner(address NFT, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return sharesHoldedByOwner[NFT][tokenId];
    }

    function getNFTTotalShares(address NFT, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return nftTotalShares[NFT][tokenId];
    }

    function getUsersShareInNFT(
        address NFT,
        uint256 tokenId,
        address user
    ) public view returns (uint256) {
        return UsersShareinNFT[NFT][tokenId][user];
    }

    function getAmountCollectedForNFT(address NFT, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return amountCollectedForNFT[NFT][tokenId];
    }
}
