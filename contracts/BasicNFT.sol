// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BasicNFT is ERC721 {
    uint256 private tokenCounter;
    string public constant TOKEN_URI =
        "ipfs://bafybeihvckbwo4cmpgm23toxynbhtefeie74f7rxu6rey7wtuxw67o2cci.ipfs.localhost:8080/";

    constructor() ERC721("Olivia", "OLI") {
        tokenCounter = 0;
    }

    function mintNFT() public returns (uint256) {
        _safeMint(msg.sender, tokenCounter);
        tokenCounter += 1;

        return tokenCounter;
    }

    function getTokenCounter() public returns (uint256) {
        return tokenCounter;
    }

    function tokenURI(
        uint256 /*tokenId*/
    ) public view override returns (string memory) {
        return TOKEN_URI;
    }
}
