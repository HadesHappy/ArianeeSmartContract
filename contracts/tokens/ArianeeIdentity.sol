pragma solidity ^0.4.23;

import "./NFTokenMetadata.sol";
//import "../tokens/ERC721Enumerable.sol";
import "./NFTokenEnumerable.sol";



import "@0xcert/ethereum-utils/contracts/ownership/Ownable.sol";

contract ArianeeIdentity is
  NFTokenMetadata, 
  NFTokenEnumerable  ,
  Ownable
{

  constructor(
  )
    public
  {
    nftName = "ArianeeIdentity";
    nftSymbol = "AriaI";
  }

  // Create or update identity for an ethereum address
  function setIdentity(string json) 
    external {

    uint256 currentId;

    if (this.balanceOf(msg.sender)>0) {
      // Update current identity
      currentId = this.tokenOfOwnerByIndex(msg.sender,0);
      super._setTokenUri(currentId,json);


    } else {
      // Mint new identity
      currentId = this.totalSupply() + 1;

      super._mint(msg.sender, currentId);

      super._setTokenUri(currentId,json);

    }

  }

  // retrieve identity for an ethereum address
  function getIdentity(address owner)
    external
    view
    returns (string) {


      if (this.balanceOf(owner)>0) {
        return this.tokenURI(this.tokenOfOwnerByIndex(owner,0));
      } else {
        return "undefined";
      }

  }


}