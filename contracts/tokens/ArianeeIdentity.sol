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
  mapping(address => bool) internal approvedList;

  /**
   * @dev Mapping from address to URI.
   */
  mapping(address => string) internal addressToUri;

  /**
   * @dev Mapping from address to imprint.
   */
  mapping(address => bytes32) internal addressToImprint;

  /**
   * @dev Mapping from address to URI.
   */
  mapping(address => string) internal addressToWaitingUri;

  /**
   * @dev Mapping from address to imprint.
   */
  mapping(address => bytes32) internal addressToWaitingImprint;

  /**
   * @dev Mapping from address to compromise date.
   */
  mapping(address => uint256) internal compromiseDate;

  /**
   * @dev Mapping from addressId to address.
   */
  mapping(bytes3=>address) internal addressListing;
   
  /**
   * @dev This emits when a new address is approved.
   */
  event AddressApprovedAdded(address _newIdentity, bytes3 _addressId);
   
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

  /**
   * @dev Slice text.
   * @param _begin first byte to return (first is 1).
   * @param _end last param to return.
   * @param _text bytes to slice.
   * @return text sliced.
   */
  function _getSlice(uint256 _begin, uint256 _end, bytes memory _text) internal pure returns (bytes memory) {
    bytes memory _a = new bytes(_end-_begin+1);
    for(uint i=0;i<=_end-_begin;i++){
        _a[i] = bytes(_text)[i+_begin-1];
    }
    return bytes(_a);    
  }

   /**
    * @dev Convert a bytes in bytes3.
    * @param _inBytes input bytes.
    * @return output bytes3.
    */
  function _convertBytesToBytes3(bytes memory _inBytes) internal pure returns (bytes3 outBytes3) {
    if (_inBytes.length == 0) {
        return 0x0;
    }

    assembly {
        outBytes3 := mload(add(_inBytes, 32))
    }
  }
  
  /**
   * @dev Add a new address to approvedList
   * @notice Can only be called by the owner, allow an address to create/update his URI and Imprint.
   * @param _newIdentity Address to authorize.
   * @return Id for address in bytes3.
   */
  function addAddressToApprovedList(address _newIdentity) public onlyOwner() returns (bytes3){
    approvedList[_newIdentity] = true;
    
    bytes memory _bytesAddress = abi.encodePacked(_newIdentity);
    bytes memory _addressIdDyn = _getSlice(1,4,_bytesAddress);
    bytes3 _addressId = _convertBytesToBytes3(_addressIdDyn);
    
    addressListing[_addressId] = _newIdentity;
    
    emit AddressApprovedAdded(_newIdentity, _addressId);
    
    return _addressId;
  }

  /**
   * @dev Remove an address from approvedList.
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
  
  
  /**
   * @dev Validate waiting informations provided by the identity.
   * @notice Can only be called by the owner of the contract.
   * @param _identity address to be validated.
   */
  function validateInformation(address _identity) public onlyOwner(){
    addressToUri[_identity] = addressToWaitingUri[_identity];
    addressToImprint[_identity] =  addressToWaitingImprint[_identity];

    emit URIValidate(_identity, addressToWaitingUri[_identity], addressToWaitingImprint[_identity]);

    delete addressToWaitingUri[_identity];
    delete addressToWaitingImprint[_identity];
  }

  /**
   * @notice Add a compromise date to an identity.
   * @dev Can only be called by the contract's owner.
   * @param _identity address compromise
   * @param _compromiseDate compromise date
   */
  function updateCompromiseDate(address _identity, uint256 _compromiseDate) public onlyOwner(){
    compromiseDate[_identity] = _compromiseDate;
    emit IdentityCompromised(_identity, _compromiseDate);
  }

  /**
   * @notice Check if an address is approved.
   * @param _identity address of the identity.
   * @return true if approved.
   */
  function addressIsApproved(address _identity) external view returns (bool _isApproved){
      _isApproved = approvedList[_identity];
  }
  
  /**
   * @notice The uri of a given identity.
   * @param _identity address of the identity.
   * @return the uri.
   */
  function addressURI(address _identity) external view returns (string memory _uri){
      _uri = addressToUri[_identity];
  }

  /**
   * @notice The imprint for a given identity.
   * @param _identity address of the identity.
   * @return true if approved.
   */
  function addressImprint(address _identity) external view returns (bytes32 _imprint){
      _imprint = addressToImprint[_identity];
  }

  /**
   * @notice The waiting uri for a given identity.
   * @param _identity address of the identity.
   * @return the waiting Uri.
   */
  function waitingURI(address _identity) external view returns(string memory _waitingUri){
      _waitingUri = addressToWaitingUri[_identity];
  }

  /**
   * @notice The waiting imprint for a given identity.
   * @param _identity address of the identity.
   * @return the waiting imprint.
   */
  function waitingImprint(address _identity) external view returns(bytes32 _waitingImprint){
      _waitingImprint = addressToWaitingImprint[_identity];
  }
  
  /**
   * @notice The compromise date for a given identity.
   * @param _identity address of the identity.
   * @return the waiting Uri.
   */
  function compromiseIdentityDate(address _identity) external view returns(uint256 _compromiseDate){
      _compromiseDate = compromiseDate[_identity];
  }

  /**
   * @notice The address for a given short id.
   * @param _id short id of the identity
   * @return the address of the identity.
   */
  function addressFromId(bytes3 _id) external view returns(address _identity){
      _identity = addressListing[_id];
  }

}

