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
  mapping(uint256 => bytes32) public encryptedInitialKey;

  // Mapping from token id to issuer
  mapping(uint256 => address) public tokenIssuer;

  // Mapping from token id to URI
  mapping(uint256 => string) public idToUri;

  // Mapping from token id to Token Access (0=view, 1=service, 2=transfert)
  mapping(uint256 => mapping(uint8 => bytes32)) public tokenAccess;

  //  Mapping from token id to TokenImprintUpdate
  mapping(uint256 => bytes32) public idToImprint;

  // mapping from token id to timestamp
  mapping(uint256 => uint256) public tokenCreation;

  // mapping from token id to lost flag
  mapping(uint256 => bool) public tokenLost;


  uint8 constant ABILITY_CREATE_ASSET = 1;

  /**
   * @dev Error constants.
   */
  string constant CAPABILITY_NOT_SUPPORTED = "007001";
  string constant TRANSFERS_DISABLED = "007002";
  string constant NOT_VALID_XCERT = "007003";
  string constant NFT_ALREADY_SET = "007006";
  string constant NOT_OWNER_OR_OPERATOR = "007004";

  bool isPaused = false;

  event IsPaused(bool isPaused);

  /**
   * @dev Pause or unpause a contract
   * @dev Can only be called by owner of the contract
   * @param _isPaused boolean to pause or unpause the contract
   */
  function setPause(bool _isPaused) external onlyOwner() {
    isPaused = _isPaused;
    emit IsPaused(_isPaused);
  }

  /**
   * @dev Modifier Check if the contract is not paused
   */
  modifier whenNotPaused(){
    require(!isPaused, "007006");
    _;
  }

  /**
   * @dev Modifier Check if the msg.sender can operate the token
   * @param _tokenId uint256 ID of the token to test
   */
  modifier canOperate(uint256 _tokenId) {
    address tokenOwner = idToOwner[_tokenId];
    require(tokenOwner == msg.sender || ownerToOperators[tokenOwner][msg.sender], NOT_OWNER_OR_OPERATOR);
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


  /**
   * @dev Public function batch function for reserveToken
   * @param _first uint256 first ID to reserve
   * @param _last uint256 last ID to reserve
   */
  function reserveTokens(uint256 _first, uint256 _last) public {
    for (uint i = _first; i <= _last; i++) {
      reserveToken(i);
    }
  }

  /**
   * @dev Public function reserve a NFT at the given ID.
   * @dev Can only be call by an authorized address
   * @param _id uint256 ID to reserve
   */
  function reserveToken(uint256 _id) public hasAbility(ABILITY_CREATE_ASSET) whenNotPaused() {
    super._create(tx.origin, _id);
  }

  /**
   * @dev Public function specify information on a reserved NFT
   * @dev Can only be called once by an NFT's operator
   * @param _id uint256 ID of the NFT to modify
   * @param _imprint bytes32 proof of the certification
   * @param _uri string URI of the JSON certification
   * @param _encryptedInitialKey bytes32 initial key
   * @param _initialKeyIsRecoveryKey bool if true set initial key as recovery key
   */
  function hydrateToken(uint256 _id, bytes32 _imprint, string memory _uri, bytes32 _encryptedInitialKey, bool _initialKeyIsRecoveryKey) public whenNotPaused() canOperate(_id) {
    require(!(tokenCreation[_id] > 0), NFT_ALREADY_SET);

    tokenIssuer[_id] = idToOwner[_id];
    encryptedInitialKey[_id] = _encryptedInitialKey;
    tokenCreation[_id] = block.timestamp;
    idToImprint[_id] = _imprint;

    idToUri[_id] = _uri;

    tokenLost[_id] = false;

    if (_initialKeyIsRecoveryKey) {
      tokenAccess[_id][2] = _encryptedInitialKey;
    }
  }

  /**
   * @dev Public function to recover the NFT for the issuer
   * @dev Works only for the issuer and if the token was created within 31 days
   * @param _id ID of the NFT to recover
   */
  function recoverTokenToIssuer(uint256 _id) public whenNotPaused() isIssuer(_id) {
    require((block.timestamp - tokenCreation[_id]) < 2678400);
    idToApproval[_id] = tx.origin;
    _transferFrom(idToOwner[_id], tokenIssuer[_id], _id);
  }


  /**
  * @dev function to check if the owner of a NFT is also the issuer
  * @param _tokenId ID of the NFT to test.
  */
  modifier isIssuer(uint256 _tokenId) {
    require(msg.sender == tokenIssuer[_tokenId]);
    _;
  }


  /**
  * @dev External function to update the tokenURI
  * @dev Can only bve called by the NFT's issuer
  * @param _tokenId id of the NFT to edit
  * @param _uri New URI for the certificate
  */
  function updateTokenURI(uint256 _tokenId, string calldata _uri) external isIssuer(_tokenId) whenNotPaused() {
    require(idToOwner[_tokenId] != address(0), NOT_VALID_XCERT);
    idToUri[_tokenId] = _uri;
  }


  /**
   * @dev External function Add an token access to a NFT
   * @dev can only be called by an NFT's operator
   * @param _tokenId uint256 id of the NFT
   * @param _encryptedTokenKey bytes32 encoded token access to add ()
   * @param _enable boolean to enable or disable the token access
   * @param _tokenType uint8 type of token access (0=view, 1=service, 2=transfer)
   */
  function addTokenAccess(uint256 _tokenId, bytes32 _encryptedTokenKey, bool _enable, uint8 _tokenType) external canOperate(_tokenId) whenNotPaused() returns (bool) {
    if (_enable) {
      tokenAccess[_tokenId][_tokenType] = _encryptedTokenKey;
    }
    else {
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
   * @dev Checks if NFT is requestable with the given token key
   * @param _tokenId uint256 id of the NFT to validate
   * @param _tokenKey token key to check
   */
  modifier canRequest(uint256 _tokenId, string memory _tokenKey) {
    require(tokenAccess[_tokenId][2] != 0x00 && keccak256(abi.encodePacked(_tokenKey)) == tokenAccess[_tokenId][2]);
    _;
  }


  /**
   * @dev Transfers the ownership of a given token ID to another address
   * @dev Requires the msg sender to have the correct tokenKey and NFT id has to be requestable
   * @dev Automaticaly approve the requester if _tokenKey is valid to allow transferFrom without removing NFT compliance
   * @dev msg.sender has to be _to
   * @param _to address to receive the ownership of the given NFT id
   * @param _tokenId uint256 ID of the token to be transferred
   * @param _tokenKey string to encode to check transfert token access
  */
  function requestFrom(address _to, uint256 _tokenId, string memory _tokenKey) public canRequest(_tokenId, _tokenKey) whenNotPaused() {
    require(msg.sender == _to);
    idToApproval[_tokenId] = _to;
    tokenAccess[_tokenId][2] = 0x00;
    _transferFrom(idToOwner[_tokenId], _to, _tokenId);
  }


  /**
   * @dev Public function to check if a NFT is viewable
   * @param _tokenId uint256 ID of the NFT to check
   */
  function isView(uint256 _tokenId) public view returns (bool) {
    return tokenAccess[_tokenId][0] != 0x00;
  }

  /**
   * @dev Public function to check if a NFT is serviceable
   * @param _tokenId uint256 ID of the NFT to check
   */
  function isService(uint256 _tokenId) public view returns (bool) {
    return tokenAccess[_tokenId][1] != 0x00;
  }


  /**
   * @dev Checks if NFT id is service ok and correct token access is given
   * @param _tokenId uint256 ID of the NFT to validate
   * @param _tokenKey string to encode to check service token access
   */
  modifier canService(uint256 _tokenId, string memory _tokenKey) {
    require(tokenAccess[_tokenId][1] != 0x00 && keccak256(abi.encodePacked(_tokenKey)) == tokenAccess[_tokenId][1]);
    _;
  }

  /**
   * @dev Public function to emit a service
   * @dev Can only be called with a valid service token access
   * @param _from address to send servuce
   * @param _tokenId uint256 ID of the NFT which receive service
   * @param _tokenKey string of the service encrypted key
   * @param _serviceType string
   * @param _description string description of the service
  */
  function serviceFrom(address _from, uint256 _tokenId, string memory _tokenKey, string memory _serviceType, string memory _description) public canService(_tokenId, _tokenKey) whenNotPaused() {
    tokenAccess[_tokenId][1] = 0x00;
    emit Service(
      _from,
      _tokenId,
      _serviceType,
      _description
    );
  }

  // lost functions
  /**
   * @dev Set a NFT as lost and block all transation
   * @param _tokenId uint256 ID of the token to set lost
   * @param _isLost boolean to set the token lost or not
  */
  function setTokenLost(uint256 _tokenId, bool _isLost) public whenNotPaused() canOperate(_tokenId) {
    tokenLost[_tokenId] = _isLost;
  }

  /**
   * @dev Check if a NFT is not lost
   * @param _tokenId uint256 ID of the token to test
  */
  modifier isTokenNotLost(uint256 _tokenId) {
    require(!tokenLost[_tokenId]);
    _;
  }

}