pragma solidity ^0.4.23;

import "../tokens/NFTokenMetadata.sol";
//import "../tokens/ERC721Enumerable.sol";
import "../tokens/NFTokenEnumerable.sol";



import "@0xcert/ethereum-utils/contracts/ownership/Ownable.sol";
 
contract ArianeeSmartAsset is
  NFTokenMetadata, 
  NFTokenEnumerable  ,
  Ownable
{


  // Mapping from token id to bool as for request as transfer knowing the tokenkey
  mapping (uint256 => bool) public isTokenRequestable;  

  // Mapping from token id to TokenKey (if requestable)
  mapping (uint256 => bytes32) public encryptedTokenKey;  

  // Mapping from token id to bool as for request for service knowing the tokenkey
  mapping (uint256 => bool) public isTokenService;  

  // Mapping from token id to TokenKey (if service)
  mapping (uint256 => bytes32) public encryptedTokenKeyService;


  /**
   * @dev Emits when a service id added to any NFT. This event emits when NFTs are
   * serviceed
   */
  event Service( 
    address indexed _from,
    uint256 indexed _tokenId,
    string serviceType,
    string description
  );


  constructor(
  )
    public
  {
    nftName = "ArianeeSmartAsset";
    nftSymbol = "AriaSA";
  }


  /**
   * @dev Public function to mint a specific token and assign metadata
   * @param _for receiver of the token to mint
   * @param value json metadata (in blockchain for now)
   */
  function createFor(address _for, string value) public returns (uint256) {
    uint256 currentToken = this.totalSupply() + 1;

    _mint(_for ,currentToken);
    _setTokenUri(currentToken,value);

    // TODO return false if value not well formatted
    return currentToken;

  }


  /**
   * @dev Public function to mint a specific token and assign metadata with token for request
   * @param _for receiver of the token to mint
   * @param value json metadata (in blockchain for now)
   */
  function createForWithToken(address _for, string value, bytes32 _encryptedTokenKey) public returns (uint256) {
    uint256 currentToken = createFor(_for, value);

    encryptedTokenKey[currentToken] = _encryptedTokenKey;
    isTokenRequestable[currentToken] = true;

    // TODO return false if value not well formatted
    return currentToken;

  }

  /**
   * @dev Public function to mint a specific token for sender and assign metadata
   * @param value json metadata (in blockchain currently)
   */
  function create (string value) public returns (uint256) {
    return createFor(msg.sender,value);
  }


   /**
   * @dev Guarantees that the msg.sender is the NFT owner.
   * @param _tokenId ID of the NFT to transfer.
   */
  modifier onlyOwnerOf(
    uint256 _tokenId
  ) {
    address tokenOwner = idToOwner[_tokenId];
    require(
      tokenOwner == msg.sender
    );

    _;
  }

  /**
   * @dev Public function to check if a token is requestable
   * @param _tokenId uint256 ID of the token to check
   */
  function isRequestable(uint256 _tokenId) public view returns (bool) {
    return isTokenRequestable[_tokenId];
  }

  /**
   * @dev Public function to set a token requestable (or not)
   * @param _tokenId uint256 ID of the token to check
   * @param _encryptedTokenKey bytes32 representation of keccak256 secretkey
   * @param _requestable bool to set on or off   
   */
  function setRequestable(uint256 _tokenId, bytes32 _encryptedTokenKey, bool _requestable) public onlyOwnerOf(_tokenId) returns (bool) {

    if (_requestable) {
      encryptedTokenKey[_tokenId] = _encryptedTokenKey;
      isTokenRequestable[_tokenId] = true;
    } else {
      isTokenRequestable[_tokenId] = false;    
    }

    return true;
  }  

  /**
   * @dev Checks if token id is requestable and correct key is given
   * @param _tokenId uint256 ID of the token to validate
   */
  modifier canRequest(uint256 _tokenId, string encryptedKey) {
    require(isTokenRequestable[_tokenId]&&keccak256(abi.encodePacked(encryptedKey)) == encryptedTokenKey[_tokenId]);
    _;
  }
  

  /** TODO
   * @dev Transfers the ownership of a given token ID to another address
   * @dev Usage of this method is discouraged, use `safeTransferFrom` whenever possible
   * @dev Requires the msg sender to have the correct tokenKey and token id is requestable
   * @param _to address to receive the ownership of the given token ID
   * @param _tokenId uint256 ID of the token to be transferred
  */
  function requestFrom(address _to, uint256 _tokenId, string encryptedKey) public canRequest(_tokenId, encryptedKey) {

    super._transfer( _to, _tokenId);
    isTokenRequestable[_tokenId] = false;    


  }





  // service event 


  /**
   * @dev Public function to check if a token is service ok
   * @param _tokenId uint256 ID of the token to check
   */
  function isService(uint256 _tokenId) public view returns (bool) {
    return isTokenService[_tokenId];
  }

  /**
   * @dev Public function to set a token service (or not)
   * @param _tokenId uint256 ID of the token to check
   * @param _encryptedTokenKey bytes32 representation of keccak256 secretkey
   * @param _requestable bool to set on or off   
   */
  function setService(uint256 _tokenId, bytes32 _encryptedTokenKey, bool _requestable) public onlyOwnerOf(_tokenId) returns (bool) {

    if (_requestable) {
      encryptedTokenKeyService[_tokenId] = _encryptedTokenKey;
      isTokenService[_tokenId] = true;
    } else {
      isTokenService[_tokenId] = false;    
    }

    return true;
  }  

  /**
   * @dev Checks if token id is service ok and correct key is given
   * @param _tokenId uint256 ID of the token to validate
   */
  modifier canService(uint256 _tokenId, string encryptedKey) {
    require(isTokenService[_tokenId]&&keccak256(abi.encodePacked(encryptedKey)) == encryptedTokenKeyService[_tokenId]);
    _;
  }
  

  /** TODO
   * @dev Transfers the ownership of a given token ID to another address
   * @dev Usage of this method is discouraged, use `safeTransferFrom` whenever possible
   * @dev Requires the msg sender to have the correct tokenKey and token id is requestable
   * @param _from address to send servuce
   * @param _tokenId uint256 ID of the token which receive service
  */
  function serviceFrom(address _from, uint256 _tokenId, string encryptedKey, string serviceType, string description) public canService(_tokenId, encryptedKey) {


   emit Service(
      _from,
      _tokenId,
      serviceType,
      description
    );

    isTokenService[_tokenId] = false;    


  }



}