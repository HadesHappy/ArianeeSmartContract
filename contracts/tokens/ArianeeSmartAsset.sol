pragma solidity 0.5.1;


import "@0xcert/ethereum-utils-contracts/src/contracts/math/safe-math.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/permission/abilitable.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/utils/address-utils.sol";

import "@0xcert/ethereum-erc721-contracts/src/contracts/nf-token-metadata-enumerable.sol";
 
contract ArianeeSmartAsset is
  NFTokenMetadataEnumerable,
  Abilitable
{

  // Mapping from token id to bool as for request as transfer knowing the tokenkey
  mapping (uint256 => bool) public isTokenRequestable;

  // Mapping from token id to TokenKey (if requestable)
  mapping (uint256 => bytes32) public encryptedTokenKey;  

  // Mapping from token id to bool as for request for service knowing the tokenkey
  mapping (uint256 => bool) public isTokenService;  

  // Mapping from token id to TokenKey (if service)
  mapping (uint256 => bytes32) public encryptedTokenKeyService;
  
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
  uint8 constant ABILITY_REVOKE_ASSET = 2;
  uint8 constant ABILITY_TOGGLE_TRANSFERS = 3;
  uint8 constant ABILITY_UPDATE_ASSET_IMPRINT = 4;

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
  function setPause(bool _isPaused) external hasAbility(ABILITY_TOGGLE_TRANSFERS) {
    require(supportedInterfaces[0xbedb86fb], CAPABILITY_NOT_SUPPORTED);
    isPaused = _isPaused;
    emit IsPaused(_isPaused);
  }
  
  /**
   * Check if the contract is not paused
   */
  modifier isNotPaused(){
      require(!isPaused);
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
  
  event TokenImprintUpdate(
    uint256 indexed _tokenId,
    bytes32 _imprint
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
   * @param _to receiver of the token to mint
   */
  
   function createFor(address _to, uint256 _id, bytes32 _imprint, string memory _uri, bytes32 _encryptedInitialKey) public hasAbility(ABILITY_CREATE_ASSET) isNotPaused() {
    super._create(_to, _id);
    idToImprint[_id] = _imprint;
    tokenIssuer[_id] = tx.origin;
    encryptedInitialKey[_id] = _encryptedInitialKey;
    idToUri[_id]=_uri;
    tokenCreation[_id] = block.timestamp;
    tokenLost[_id] = false;
    
    tokenAccess[_id][0]=false;
    tokenAccess[_id][1]=false;
    tokenAccess[_id][2]=false;
  }


  /**
   * @dev Public function to mint a specific token and assign metadata with token for request
   * @param _to receiver of the token to mint
   */
  function createForWithToken(address _to, uint256 _id, bytes32 _imprint, string memory _uri, bytes32 _encryptedInitialKey, bytes32 _encryptedTokenKey) public isNotPaused() {
    createFor(_to, _id, _imprint, _uri, _encryptedInitialKey);
    
    encryptedTokenKey[_id] = _encryptedTokenKey;
    tokenAccess[_id][2]=true;
  }
  
  /**
   * @dev Public function to recover the NFT for the issuer
   * @dev Works only for the issuer and if the token was created within 31 days
   * @param _id ID of the NFT to recover
   */
  function getTokenToIssuer(uint256 _id) public isNotPaused()  {
      require((block.timestamp - tokenCreation[_id] )  < 2678400);
      require(tx.origin == tokenIssuer[_id]);
      idToApproval[_id] = tx.origin;
      _transferFrom(idToOwner[_id], tokenIssuer[_id], _id);
  }

  /**
   * @dev Public function to mint a specific token for sender and assign metadata
   * OLD CODE
   */
  /*function create (uint256 _id, bytes32 _imprint) public {
    return createFor(msg.sender, _id, _imprint);
  }*/
  
  /**
  * @dev function to check if the owner of a token is also the issuer
  */
  modifier ownerIsIssuer(uint256 _tokenId) {
      require(idToOwner[_tokenId] == tokenIssuer[_tokenId]);
        _;   
  }
  
  
  /**
  * @dev Function to update the tokenURI
  * @dev Works only if the owner is also the issuer of the token 
  * @param _tokenId ID of the NFT to edit
  * @param _imprint New imprit for the NFT
  * @param _uri New URI for the certificate
  */
  function updateTokenURI(
    uint256 _tokenId,
    bytes32 _imprint,
    string calldata _uri
  )
    external
    ownerIsIssuer(_tokenId)
    isNotPaused()
  {
    require(supportedInterfaces[0xbda0e852], CAPABILITY_NOT_SUPPORTED);
    require(idToOwner[_tokenId] != address(0), NOT_VALID_XCERT);
    idToUri[_tokenId] = _uri;
    idToImprint[_tokenId] = _imprint;
    emit TokenImprintUpdate(_tokenId, _imprint);
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
    return tokenAccess[_tokenId][2] == true;
  }

  /**
   * @dev Public function to set a token requestable (or not)
   * @param _tokenId uint256 ID of the token to check
   * @param _encryptedTokenKey bytes32 representation of keccak256 secretkey
   * @param _requestable bool to set on or off   
   */
  function setRequestable(uint256 _tokenId, bytes32 _encryptedTokenKey, bool _requestable) public onlyOwnerOf(_tokenId) isNotPaused() returns (bool) {

    if (_requestable) {
      encryptedTokenKey[_tokenId] = _encryptedTokenKey;
      tokenAccess[_tokenId][2]=true;
    } else {
      tokenAccess[_tokenId][2]=false;
    }

    return true;
  }  


  /**
   * @dev Checks if token id is requestable and correct key is given
   * @param _tokenId uint256 ID of the token to validate
   */
  modifier canRequest(uint256 _tokenId, bytes32 encryptedKey) {
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
  function requestFrom(address _to, uint256 _tokenId, bytes32 encryptedKey) public canRequest(_tokenId, encryptedKey) isNotPaused() {
    super._transferFrom(msg.sender, _to, _tokenId);
    tokenAccess[_tokenId][2] = false;    
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
  function setService(uint256 _tokenId, bytes32 _encryptedTokenKey, bool _requestable) public onlyOwnerOf(_tokenId) isNotPaused() returns (bool) {

    if (_requestable) {
      encryptedTokenKeyService[_tokenId] = _encryptedTokenKey;
      tokenAccess[_tokenId][1] = true;
    } else {
      tokenAccess[_tokenId][1] = false;
    }

    return true;
  }  

  /**
   * @dev Checks if token id is service ok and correct key is given
   * @param _tokenId uint256 ID of the token to validate
   */
  modifier canService(uint256 _tokenId, bytes32 encryptedKey) {
    require(tokenAccess[_tokenId][1]&&keccak256(abi.encodePacked(encryptedKey)) == encryptedTokenKeyService[_tokenId]);
    _;
  }
  

  /** TODO
   * @dev Transfers the ownership of a given token ID to another address
   * @dev Usage of this method is discouraged, use `safeTransferFrom` whenever possible
   * @dev Requires the msg sender to have the correct tokenKey and token id is requestable
   * @param _from address to send servuce
   * @param _tokenId uint256 ID of the token which receive service
  */
  function serviceFrom(address _from, uint256 _tokenId, bytes32 encryptedKey,string memory serviceType, string memory description) public canService(_tokenId, encryptedKey) isNotPaused() {

   emit Service(
      _from,
      _tokenId,
      serviceType,
      description
    );

    tokenAccess[_tokenId][1] = false;    
  }
  
  /**
   * @dev Set a NFT as lost and block all transation
   * @param _tokenId uint256 ID of the token to set lost
   * @param _isLost boolean to set the token lost or not
  */
  function setTokenLost(uint256 _tokenId, bool _isLost) public isNotPaused() onlyOwnerOf(_tokenId){
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