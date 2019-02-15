pragma solidity 0.5.1;

import "@0xcert/ethereum-utils-contracts/src/contracts/permission/ownable.sol";

contract ArianeeIdentity is
Ownable
{

  /**
  * @dev A descriptive name.
  */
  string internal name;

  /**
  * @dev An abbreviated name.
  */
  string internal symbol;

  /**
  * @dev Mapping from address to whitelist boolean
  */
  mapping(address => bool) public whitelist;

  /**
  * @dev Mapping from address to URI.
  */
  mapping(address => string) public addressToUri;

  /**
  * @dev Mapping from address to imprint.
  */
  mapping(address => bytes32) public addressToImprint;

  /**
  * @dev Mapping from address to compromise date.
  */
  mapping(address => uint256) public compromiseDate;

  constructor() public{
    name = "Arianee Identity";
    symbol = "AriaI";
  }

  /**
  * @dev Check if an address is whitelisted.
  * @param _identity The address to check.
  */
  modifier isWhitelisted(address _identity){
    require(whitelist[_identity]);
    _;
  }
  /**
  * @dev Add a new address to whitelist
  * @notice Can only be called by the owner, allow an address to create/update his URI and Imprint.
  * @param _newIdentity Address to authorize.
  */
  function addAddressTowhitelist(address _newIdentity) public onlyOwner(){
    whitelist[_newIdentity] = true;
  }

  /**
  * @dev Update URI and Imprint of an address.
  * @param _uri URI to update.
  * @param _imprint Imprint to update
  */
  function updateInformations(string memory _uri, bytes32 _imprint) public isWhitelisted(msg.sender){
    addressToUri[msg.sender] = _uri;
    addressToImprint[msg.sender] = _imprint;
  }

  /**
   * @dev Add a compromise date to an identity.
   * @notice Can only be called by the contract's owner.
   * @param _identity address compromise
   * @param _compromiseDate compromise date
   */
  function updateCompromiseDate(address _identity, uint256 _compromiseDate) public onlyOwner(){
    compromiseDate[_identity] = _compromiseDate;
  }

  /**
  * @dev Get a token URI
  * @param _address address of the identity
  */
  function tokenURI(address _address) external view returns (string memory){
    return addressToUri[_address];
  }

}

