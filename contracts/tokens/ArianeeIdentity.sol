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
   * @dev Mapping from address to approvedList boolean
   */
  mapping(address => bool) public approvedList;

  /**
   * @dev Mapping from address to URI.
   */
  mapping(address => string) public addressToUri;

  /**
   * @dev Mapping from address to imprint.
   */
  mapping(address => bytes32) public addressToImprint;

  /**
   * @dev Mapping from address to URI.
   */
  mapping(address => string) public addressToWaitingUri;

  /**
   * @dev Mapping from address to imprint.
   */
  mapping(address => bytes32) public addressToWaitingImprint;

  /**
   * @dev Mapping from address to compromise date.
   */
  mapping(address => uint256) public compromiseDate;

  /**
   * 
   */
   address[] public addressListing;

  constructor() public{
    name = "Arianee Identity";
    symbol = "AriaI";
  }

  /**
   * @dev Check if an address is approved.
   * @param _identity The address to check.
   */
  modifier isApproved(address _identity){
    require(approvedList[_identity]);
    _;
  }
  /**
   * @dev Add a new address to approvedList
   * @notice Can only be called by the owner, allow an address to create/update his URI and Imprint.
   * @param _newIdentity Address to authorize.
   */
  function addAddressToApprovedList(address _newIdentity) public onlyOwner() returns (uint256){
    approvedList[_newIdentity] = true;
    uint256 _addressId = addressListing.push(_newIdentity);
    return _addressId;
  }
  
 /**
  * @dev remove an address from approvedList.
  * @notice Can only be called by the owner.
  * @param _identity to delete from the approvedList.
  */
  function removeAddressFromApprovedList(address _identity) public onlyOwner(){
      approvedList[_identity] = false;
  }

  /**
   * @dev Update URI and Imprint of an address.
   * @param _uri URI to update.
   * @param _imprint Imprint to update
   */
  function updateInformations(string memory _uri, bytes32 _imprint) public isApproved(msg.sender){
    addressToWaitingUri[msg.sender] = _uri;
    addressToWaitingImprint[msg.sender] = _imprint;
  }
  
  function validateInformation(address _identity) public onlyOwner(){
      addressToUri[_identity] = addressToWaitingUri[_identity];
      addressToImprint[_identity] =  addressToWaitingImprint[_identity];
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

