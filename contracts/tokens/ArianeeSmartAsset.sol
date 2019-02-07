pragma solidity 0.5.1;


import "@0xcert/ethereum-utils-contracts/src/contracts/math/safe-math.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/permission/abilitable.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/permission/ownable.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/utils/address-utils.sol";

import "@0xcert/ethereum-erc721-contracts/src/contracts/nf-token-metadata-enumerable.sol";
 
contract ArianeeSmartAsset is
  NFTokenMetadataEnumerable,
  Abilitable,
  Ownable
{
  
  // Mapping from token id to initial key
  mapping (uint256 => bytes32) public encryptedInitialKey;

  // Mapping from token id to issuer
  mapping (uint256 => address) public tokenIssuer;
  
  // Mapping from token id to URI
  mapping(uint256 => string) idToUri;
  
  mapping (uint256=> mapping(uint256 => bool)) tokenAccess; // 0=view;1=service;2=transfert
  
  //  Mapping from token id to TokenImprintUpdate
  mapping (uint256 => bytes32) internal idToImprint;
  
  // mapping from token id to timestamp
  mapping (uint256 => uint256) public tokenCreation;
  
  // mapping from token id to lost flag
  mapping (uint256 => bool) public tokenLost;
  
  
  uint8 constant ABILITY_CREATE_ASSET = 1;

  /**
   * @dev Error constants.
   */
  string constant CAPABILITY_NOT_SUPPORTED = "007001";
  string constant TRANSFERS_DISABLED = "007002";
  string constant NOT_VALID_XCERT = "007003";
  string constant NOT_OWNER_OR_OPERATOR = "007004";
  
  bool isPaused = false;
  
   event IsPaused(bool isPaused);
   /**
    * @dev Pause or unpause a contract
    * @param _isPaused boolean to pause or unpause the contract
    */
  function setPause(bool _isPaused) external onlyOwner() {
    isPaused = _isPaused;
    emit IsPaused(_isPaused);
  }
  
  /**
   * Check if the contract is not paused
   */
  modifier whenNotPaused(){
      require(!isPaused);
      _;
  }
  
  modifier canOperate(uint256 _tokenId) {
        address tokenOwner = idToOwner[_tokenId];
        require(tokenOwner == msg.sender || ownerToOperators[tokenOwner][msg.sender],NOT_OWNER_OR_OPERATOR);
        _;
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
    
    function reserveTokens(uint256 _first, uint256 _last) public {
        for(uint i = _first; i<=_last; i++){
            reserveToken(i);
        }
    }

    function reserveToken(uint256 _id) public hasAbility(ABILITY_CREATE_ASSET) whenNotPaused() returns (bool){
        super._create(tx.origin, _id);
        return true;
    }
    
  /**
   * @dev Public function to mint a specific token and assign metadata
   */
   function createFor(uint256 _id, bytes32 _imprint, string memory _uri, bytes32 _encryptedInitialKey, bool _initialKeyIsRecoveryKey) public whenNotPaused() canOperate(_id) {
    
    tokenIssuer[_id] = idToApproval[_id];
    encryptedInitialKey[_id] = _encryptedInitialKey;
    tokenCreation[_id] = block.timestamp;
    idToImprint[_id] = _imprint;
    
    idToUri[_id]=_uri;
    
    tokenLost[_id] = false;
    
    if(_initialKeyIsRecoveryKey){
        tokenAccess[_id][2]= _encryptedInitialKey; // set transfer key 
    }
  }

  /**
   * @dev Public function to recover the NFT for the issuer
   * @dev Works only for the issuer and if the token was created within 31 days
   * @param _id ID of the NFT to recover
   */
  function recoverTokenToIssuer(uint256 _id) public whenNotPaused()  {
      require((block.timestamp - tokenCreation[_id] )  < 2678400);
      require(tx.origin == tokenIssuer[_id]);
      idToApproval[_id] = tx.origin;
      _transferFrom(idToOwner[_id], tokenIssuer[_id], _id);
  }

  
  /**
  * @dev function to check if the owner of a token is also the issuer
  */
  modifier isIssuer(uint256 _tokenId) {
      require(msg.sender == tokenIssuer[_tokenId]);
        _;   
  }
  
  
  /**
  * @dev Function to update the tokenURI
  * @dev Works only if the owner is also the issuer of the token 
  * @param _tokenId ID of the NFT to edit
  * @param _uri New URI for the certificate
  */
  function updateTokenURI(
    uint256 _tokenId,
    string calldata _uri
  )
    external
    isIssuer(_tokenId)
    whenNotPaused()
  {
    require(idToOwner[_tokenId] != address(0), NOT_VALID_XCERT);
    idToUri[_tokenId] = _uri;
  }
 
 
 /**
  * 
  */
  function addTokenKey(uint256 _tokenId, bytes32 _encryptedTokenKey, bool _enable, uint8 _tokenType) public canOperate(_tokenId) whenNotPaused() returns (bool) {
      if(_enable){
          tokenAccess[_tokenId][_tokenType] = _encryptedTokenKey;
      }
      else{
          tokenAccess[_tokenId][_tokenType] = 0x00;
      }
      return true;
  }

  /**
   * @dev Public function to check if a token is requestable
   * @param _tokenId uint256 ID of the token to check
   */
  function isRequestable(uint256 _tokenId) public view returns (bool) {
    return tokenAccess[_tokenId][2] != 0x00;
  }
  
  /**
   * @dev Checks if token id is requestable and correct key is given
   * @param _tokenId uint256 ID of the token to validate
   */
  modifier canRequest(uint256 _tokenId, string memory encryptedKey) {
    require(tokenAccess[_tokenId][2] != 0x00 && keccak256(abi.encodePacked(encryptedKey)) == tokenAccess[_tokenId][2]);
    _;
  }
  
  
  /** TODO
   * @dev Transfers the ownership of a given token ID to another address
   * @dev Usage of this method is discouraged, use `safeTransferFrom` whenever possible
   * @dev Requires the msg sender to have the correct tokenKey and token id is requestable
   * @param _to address to receive the ownership of the given token ID
   * @param _tokenId uint256 ID of the token to be transferred
  */
  function requestFrom(address _to, uint256 _tokenId, string memory encryptedKey) public canRequest(_tokenId, encryptedKey) whenNotPaused() {
    tokenAccess[_tokenId][2] = 0x00;
    super._transferFrom(idToOwner[_tokenId], _to, _tokenId);
  }
  
  
  /**
   * @dev Public function to check if a token is view ok
   * @param _tokenId uint256 ID of the token to check
   */
  function isView(uint256 _tokenId) public view returns (bool) {
        return tokenAccess[_tokenId][0] != 0x00;
  }
  
  /**
   * @dev Public function to check if a token is service ok
   * @param _tokenId uint256 ID of the token to check
   */
  function isService(uint256 _tokenId) public view returns (bool) {
    return tokenAccess[_tokenId][1] != 0x00;
  }
  
  
  /**
   * @dev Checks if token id is service ok and correct key is given
   * @param _tokenId uint256 ID of the token to validate
   */
  modifier canService(uint256 _tokenId, string memory encryptedKey) {
    require(tokenAccess[_tokenId][1] != 0x00 && keccak256(abi.encodePacked(encryptedKey)) == tokenAccess[_tokenId][1]);
    _;
  }
  
    /** TODO
   * @dev Transfers the ownership of a given token ID to another address
   * @dev Usage of this method is discouraged, use `safeTransferFrom` whenever possible
   * @dev Requires the msg sender to have the correct tokenKey and token id is requestable
   * @param _from address to send servuce
   * @param _tokenId uint256 ID of the token which receive service
  */
  function serviceFrom(address _from, uint256 _tokenId, string memory encryptedKey,string memory serviceType, string memory description) public canService(_tokenId, encryptedKey) whenNotPaused() {

   emit Service(
      _from,
      _tokenId,
      serviceType,
      description
    );

    tokenAccess[_tokenId][1] = 0x00;
  }
  
  // lost functions
  /**
   * @dev Set a NFT as lost and block all transation
   * @param _tokenId uint256 ID of the token to set lost
   * @param _isLost boolean to set the token lost or not
  */
  function setTokenLost(uint256 _tokenId, bool _isLost) public whenNotPaused() canOperate(_tokenId){
      tokenLost[_tokenId] = _isLost;
  }
  
  /**
   * @dev Check if a NFT is not lost
  */
  modifier isTokenNotLost(uint256 _tokenId) {
      require(!tokenLost[_tokenId]);
      _;
  }


}