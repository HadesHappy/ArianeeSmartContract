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
  /**
   * @dev Mapping from token id to encrypted initial key.
   */
  mapping(uint256 => bytes32) public encryptedInitialKey;

  /**
   * @dev Mapping from token id to issuer.
   */
  mapping(uint256 => address) public tokenIssuer;

  /**
   * @dev Mapping from token id to URI.
   */
  mapping(uint256 => string) public idToUri;

  /**
   * @dev Mapping from token id to Token Access (0=view, 1=service, 2=transfer).
   */
  mapping(uint256 => mapping(uint8 => bytes32)) public tokenAccess;

  /**
   * @dev Mapping from token id to TokenImprintUpdate.
   */
  mapping(uint256 => bytes32) public idToImprint;

  /**
   * @dev Mapping from token id to timestamp.
   */
  mapping(uint256 => uint256) public tokenCreation;

  /**
   * @dev Mapping from token id to lost flag.
   */
  mapping(uint256 => bool) public tokenLost;

  /**
   * @dev Mapping from token id to lost flag.
   */
  mapping(uint256 => uint256) public tokenRecoveryTimestamp;


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
   * @dev Pause or unpause a contract.
   * @notice Can only be called by owner of the contract.
   * @param _isPaused boolean to pause or unpause the contract.
   */
  function setPause(bool _isPaused) external onlyOwner() {
    isPaused = _isPaused;
    emit IsPaused(_isPaused);
  }

  /**
   * @dev Check if the contract is not paused.
   */
  modifier whenNotPaused(){
    require(!isPaused, "007006");
    _;
  }

  /**
   * @dev Check if the msg.sender can operate the NFT.
   * @param _tokenId ID of the NFT to test.
   * @param _operator Address to test.
   */
  modifier canOperate(uint256 _tokenId, address _operator) {
    address tokenOwner = idToOwner[_tokenId];
    require(tokenOwner == _operator || ownerToOperators[tokenOwner][_operator], NOT_OWNER_OR_OPERATOR);
    _;
  }

  constructor(
  )
  public
  {
    nftName = "ArianeeSmartAsset";
    nftSymbol = "AriaSA";
  }

  /**
   * @dev Batch function for reserveToken.
   * @param _first First ID to reserve.
   * @param _last Last ID to reserve.
   */
  function reserveTokens(uint256 _first, uint256 _last) public {
    for (uint i = _first; i <= _last; i++) {
      reserveToken(i);
    }
  }

  /**
   * @dev Reserve a NFT at the given ID.
   * @notice Can only be called by an authorized address.
   * @param _tokenId ID to reserve.
   */
  function reserveToken(uint256 _tokenId) public hasAbility(ABILITY_CREATE_ASSET) whenNotPaused() {
    super._create(tx.origin, _tokenId);
  }

  /**
   * @dev Specify information on a reserved NFT.
   * @notice Can only be called once and by an NFT's operator.
   * @param _tokenId ID of the NFT to modify.
   * @param _imprint Proof of the certification.
   * @param _uri URI of the JSON certification.
   * @param _encryptedInitialKey Initial encrypted key.
   * @param _tokenRecoveryTimestamp Limit date for the issuer to be able to transfer back the NFT.
   * @param _initialKeyIsRequestKey If true set initial key as request key.
   */
  function hydrateToken(uint256 _tokenId, bytes32 _imprint, string memory _uri, bytes32 _encryptedInitialKey, uint256 _tokenRecoveryTimestamp, bool _initialKeyIsRequestKey) public hasAbility(ABILITY_CREATE_ASSET) whenNotPaused() canOperate(_tokenId, tx.origin) {
    require(!(tokenCreation[_tokenId] > 0), NFT_ALREADY_SET);

    tokenIssuer[_tokenId] = idToOwner[_tokenId];
    encryptedInitialKey[_tokenId] = _encryptedInitialKey;
    tokenCreation[_tokenId] = block.timestamp;
    idToImprint[_tokenId] = _imprint;
    tokenRecoveryTimestamp[_tokenId] = _tokenRecoveryTimestamp;

    idToUri[_tokenId] = _uri;

    tokenLost[_tokenId] = false;

    if (_initialKeyIsRequestKey) {
      tokenAccess[_tokenId][2] = _encryptedInitialKey;
    }
  }

  /**
   * @dev Recover the NFT to the issuer.
   * @notice Works only if called by the issuer and if called before the token Recovery Timestamp of the NFT.
   * @param _tokenId ID of the NFT to recover.
   */
  function recoverTokenToIssuer(uint256 _tokenId) public whenNotPaused() isIssuer(_tokenId) {
    require(block.timestamp < tokenRecoveryTimestamp[_tokenId]);
    idToApproval[_tokenId] = tokenIssuer[_tokenId];
    _transferFrom(idToOwner[_tokenId], tokenIssuer[_tokenId], _tokenId);
  }

  /**
  * @dev Check if msg.sender is the issuer of a NFT.
  * @param _tokenId ID of the NFT to test.
  */
  modifier isIssuer(uint256 _tokenId) {
    require(msg.sender == tokenIssuer[_tokenId]);
    _;
  }

  /**
   * @dev External function to update the tokenURI.
   * @notice Can only be called by the NFT's issuer.
   * @param _tokenId ID of the NFT to edit.
   * @param _uri New URI for the certificate.
   */
  function updateTokenURI(uint256 _tokenId, string calldata _uri) external isIssuer(_tokenId) whenNotPaused() {
    require(idToOwner[_tokenId] != address(0), NOT_VALID_XCERT);
    idToUri[_tokenId] = _uri;
  }

  /**
   * @dev return the URI of a NFT.
   * @param _tokenId uint256 ID of the NFT.
   * @return URI of the NFT.
   */
  function tokenURI(uint256 _tokenId) external view returns (string memory){
    return idToUri[_tokenId];
  }

  /**
   * @dev Add a token access to a NFT.
   * @notice can only be called by an NFT's operator.
   * @param _tokenId ID of the NFT.
   * @param _encryptedTokenKey Encoded token access to add.
   * @param _enable Enable or disable the token access.
   * @param _tokenType Type of token access (0=view, 1=service, 2=transfer).
   * @return true.
   */
  function addTokenAccess(uint256 _tokenId, bytes32 _encryptedTokenKey, bool _enable, uint8 _tokenType) external canOperate(_tokenId, msg.sender) whenNotPaused() returns (bool) {
    if (_enable) {
      tokenAccess[_tokenId][_tokenType] = _encryptedTokenKey;
    }
    else {
      tokenAccess[_tokenId][_tokenType] = 0x00;
    }
    return true;
  }

  /**
   * @dev Check if a token is requestable.
   * @param _tokenId uint256 ID of the token to check.
   * @return True if the NFT is requestable.
   */
  function isRequestable(uint256 _tokenId) public view returns (bool) {
    return tokenAccess[_tokenId][2] != 0x00;
  }

  /**
   * @dev Checks if NFT is requestable with the given token key.
   * @param _tokenId uint256 ID of the NFT to validate.
   * @param _tokenKey token key to check.
   */
  modifier canRequest(uint256 _tokenId, string memory _tokenKey) {
    require(isTokenValid(_tokenId, _tokenKey, 2));
    _;
  }

  /**
   * @dev Check if a token access is valid.
   * @param _tokenId ID of the NFT to validate.
   * @param _tokenKey String to encode to check transfer token access.
   * @param _tokenType Type of token access (0=view, 1=service, 2=transfer).
   */
  function isTokenValid(uint256 _tokenId, string memory _tokenKey, uint8 _tokenType) public view returns (bool){
    return tokenAccess[_tokenId][_tokenType] != 0x00 && keccak256(abi.encodePacked(_tokenKey)) == tokenAccess[_tokenId][_tokenType];
  }

  /**
   * @dev Transfers the ownership of a NFT to another address
   * @notice Requires the msg sender to have the correct tokenKey and NFT has to be requestable.
   * Automatically approve the requester if _tokenKey is valid to allow transferFrom without removing ERC721 compliance.
   * @param _tokenId ID of the NFT to transfer.
   * @param _tokenKey String to encode to check transfer token access.
   * @param _keepRequestToken If false erase the access token of the NFT.
   */
  function requestToken(uint256 _tokenId, string memory _tokenKey, bool _keepRequestToken) public hasAbility(ABILITY_CREATE_ASSET) canRequest(_tokenId, _tokenKey) whenNotPaused() {
    idToApproval[_tokenId] = tx.origin;
    if(!_keepRequestToken){
        tokenAccess[_tokenId][2] = 0x00;    
    }
    _transferFrom(idToOwner[_tokenId], tx.origin, _tokenId);
  }

  /**
   * @dev Check if a NFT is viewable.
   * @param _tokenId ID of the NFT to check.
   * @return True if the NFT is viewable.
   */
  function isView(uint256 _tokenId) public view returns (bool) {
    return tokenAccess[_tokenId][0] != 0x00;
  }

  /**
   * @dev Check if a NFT is serviceable.
   * @param _tokenId ID of the NFT to check.
   * @return True if the NFT is serviceable.
   */
  function isService(uint256 _tokenId) public view returns (bool) {
    return tokenAccess[_tokenId][1] != 0x00;
  }

  /**
   * @dev Checks if NFT id is service ok and correct token access is given.
   * @param _tokenId ID of the NFT to validate.
   * @param _tokenKey String to encode to check service token access.
   */
  modifier canService(uint256 _tokenId, string memory _tokenKey) {
    require(isTokenValid(_tokenId, _tokenKey, 1));
    _;
  }

  /**
   * @dev Emit a service.
   * @notice Can only be called with a valid service token access.
   * @param _from Address of the service's origin.
   * @param _tokenId ID of the NFT which receive service.
   * @param _tokenKey String of the service encrypted key.
   * @param _serviceType Type of the service.e
   * @param _description Description of the service.
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

  /**
   * @dev Emits when a service id added to any NFT. This event emits when NFTs are serviceed.
   */
  event Service(
    address indexed _from,
    uint256 indexed _tokenId,
    string serviceType,
    string description
  );

  /**
   * @dev Set a NFT as lost.
   * @param _tokenId  ID of the token to set lost.
   * @param _isLost Boolean to set the token lost or not.
   */
  function setTokenLost(uint256 _tokenId, bool _isLost) public whenNotPaused() canOperate(_tokenId, msg.sender) {
    tokenLost[_tokenId] = _isLost;
  }

}