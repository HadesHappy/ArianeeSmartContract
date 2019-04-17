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
   * @dev Mapping from addressId to address.
   */
   mapping(bytes4=>address) public addressListing;
   
   /**
    * @dev This emits when a new address is approved.
    */
   event AddressApprovedAdded(address _newIdentity, bytes4 _addressId);
   
   /**
    * @dev This emits when an address is removed from approvedList.
    */
   event AddressApprovedRemoved(address _newIdentity);
   
   /**
    * @dev This emits when a new address is approved.
    */
   event URIUpdated(address _identity, string _uri, bytes32 _imprint);
   
   /**
    * @dev This emits when an identity change its URI and Imprint.
    */
   event URIValidate(address _identity, string _uri, bytes32 _imprint);
   
   /**
    * @dev This emits when an identity change is validated by the contract owner.
    */
   event IdentityCompromised(address _identity, uint256 _compromiseDate);
   
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


  function _getSlice(uint256 begin, uint256 end, bytes memory text) public pure returns (bytes memory) {
    bytes memory a = new bytes(end-begin+1);
    for(uint i=0;i<=end-begin;i++){
        a[i] = bytes(text)[i+begin-1];
    }
    return bytes(a);    
  }

  function convertBytesToBytes4(bytes memory inBytes) internal pure returns (bytes4 outBytes4) {
    if (inBytes.length == 0) {
        return 0x0;
    }

    assembly {
        outBytes4 := mload(add(inBytes, 32))
    }
  }
  
  
  /**
   * @dev Add a new address to approvedList
   * @notice Can only be called by the owner, allow an address to create/update his URI and Imprint.
   * @param _newIdentity Address to authorize.
   * @return Id for address in bytes4.
   */
  function addAddressToApprovedList(address _newIdentity) public onlyOwner() returns (bytes4){
    approvedList[_newIdentity] = true;
    
    bytes memory _bytesAddress = abi.encodePacked(_newIdentity);
    bytes memory _addressIdDyn = _getSlice(1,6,_bytesAddress);
    bytes4 _addressId = convertBytesToBytes4(_addressIdDyn);
    
    addressListing[_addressId] = _newIdentity;
    
    emit AddressApprovedAdded(_newIdentity, _addressId);
    
    return _addressId;
  }

 /**
  * @dev remove an address from approvedList.
  * @notice Can only be called by the owner.
  * @param _identity to delete from the approvedList.
  */
  function removeAddressFromApprovedList(address _identity) public onlyOwner(){
      approvedList[_identity] = false;
      emit AddressApprovedRemoved(_identity);
  }

  /**
   * @dev Update URI and Imprint of an address.
   * @param _uri URI to update.
   * @param _imprint Imprint to update
   */
  function updateInformations(string memory _uri, bytes32 _imprint) public isApproved(msg.sender){
    addressToWaitingUri[msg.sender] = _uri;
    addressToWaitingImprint[msg.sender] = _imprint;
    emit URIUpdated(msg.sender, _uri, _imprint);
  }
  
  function validateInformation(address _identity) public onlyOwner(){
      addressToUri[_identity] = addressToWaitingUri[_identity];
      addressToImprint[_identity] =  addressToWaitingImprint[_identity];
      
      emit URIValidate(_identity, addressToWaitingUri[_identity], addressToWaitingImprint[_identity]);
      
      delete addressToWaitingUri[_identity];
      delete addressToWaitingImprint[_identity];
  }

  /**
   * @dev Add a compromise date to an identity.
   * @notice Can only be called by the contract's owner.
   * @param _identity address compromise
   * @param _compromiseDate compromise date
   */
  function updateCompromiseDate(address _identity, uint256 _compromiseDate) public onlyOwner(){
    compromiseDate[_identity] = _compromiseDate;
    emit IdentityCompromised(_identity, _compromiseDate);
  }

  /**
   * @dev Get a token URI
   * @param _address address of the identity
   */
  function tokenURI(address _address) external view returns (string memory){
    return addressToUri[_address];
  }
  

}

