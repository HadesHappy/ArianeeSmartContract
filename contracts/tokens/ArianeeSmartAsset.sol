pragma solidity 0.5.1;


import "@0xcert/ethereum-utils-contracts/src/contracts/math/safe-math.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/permission/abilitable.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/permission/ownable.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/utils/address-utils.sol";
import "./Pausable.sol";

import "@0xcert/ethereum-erc721-contracts/src/contracts/nf-token-metadata-enumerable.sol";

contract ArianeeWhitelist {
    function addWhitelistedAddress(uint256 _tokenId, address _address) public;
}

contract ArianeeSmartAsset is
NFTokenMetadataEnumerable,
Abilitable,
Ownable,
Pausable
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
   * @dev Mapping from token id to Token Access (0=view, 1=transfer).
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
  
  /**
   * @dev Mapping from token id to recovery request bool. 
   */
  mapping(uint256=>bool) recoveryRequest;
  
  /**
   * @dev Mapping from token id to total rewards for this NFT.
   */
  mapping(uint256=>uint256) public rewards;


  uint8 constant ABILITY_CREATE_ASSET = 1;

  /**
   * @dev Error constants.
   */
  string constant CAPABILITY_NOT_SUPPORTED = "007001";
  string constant TRANSFERS_DISABLED = "007002";
  string constant NOT_VALID_XCERT = "007003";
  string constant NFT_ALREADY_SET = "007006";
  string constant NOT_OWNER_OR_OPERATOR = "007004";

  ArianeeWhitelist arianeeWhitelist;
  
  
  /**
   * @dev This emits when a token is hydrated.
   */
   event Hydrated(uint256 _tokenId, bytes32 _imprint, string _uri, bytes32 _encryptedInitialKey, uint256 _tokenRecoveryTimestamp, bool _initialKeyIsRequestKey, uint256 _tokenCreation);
   
   /**
    * @dev This emits when a issuer request a NFT recovery.
    */
  event RecoveryRequestUpdated(uint256 _tokenId, bool _active);
  
  /**
   * @dev This emits when a NFT is recovered to the issuer.
   */
   event TokenRecovered(uint256 _token);
   
   /**
    * @dev This emits when a NFT's URI is udpated.
    */
    event TokenURIUpdated(uint256 _tokenId, string URI);
    
   /**
    * @dev This emits when a token access is added.
    */
    event tokenAccessAdded(uint256 _tokenId, bytes32 _encryptedTokenKey, bool _enable, uint8 _tokenType);
     
  
  /**
   * @dev Check if the msg.sender can operate the NFT.
   * @param _tokenId ID of the NFT to test.
   * @param _operator Address to test.
   */
  modifier isOperator(uint256 _tokenId, address _operator) {
      require(canOperate(_tokenId, _operator), NOT_OWNER_OR_OPERATOR);
    _;
  }
  
  function canOperate(uint256 _tokenId, address _operator) view public returns (bool){
      address tokenOwner = idToOwner[_tokenId];
      return tokenOwner == _operator || ownerToOperators[tokenOwner][_operator];
  }

  constructor(
      address _arianeeWhitelistAddress
  )
  public
  {
    nftName = "ArianeeSmartAsset";
    nftSymbol = "AriaSA";
    arianeeWhitelist = ArianeeWhitelist(address(_arianeeWhitelistAddress));
  }

  /**
   * @dev Reserve a NFT at the given ID.
   * @notice Can only be called by an authorized address.
   * @param _tokenId ID to reserve.
   * @param _to receiver of the token.
   * @param _rewards total rewards of this NFT.
   */
  function reserveToken(uint256 _tokenId, address _to, uint256 _rewards) public hasAbility(ABILITY_CREATE_ASSET) whenNotPaused() {
    super._create(_to, _tokenId);
    rewards[_tokenId] = _rewards;
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
  function hydrateToken(uint256 _tokenId, bytes32 _imprint, string memory _uri, bytes32 _encryptedInitialKey, uint256 _tokenRecoveryTimestamp, bool _initialKeyIsRequestKey) public hasAbility(ABILITY_CREATE_ASSET) whenNotPaused() isOperator(_tokenId, tx.origin) returns(uint256){
    require(!(tokenCreation[_tokenId] > 0), NFT_ALREADY_SET);
    uint256 _tokenCreation = block.timestamp;
    
    tokenIssuer[_tokenId] = idToOwner[_tokenId];
    encryptedInitialKey[_tokenId] = _encryptedInitialKey;
    tokenCreation[_tokenId] = _tokenCreation;
    idToImprint[_tokenId] = _imprint;
    tokenRecoveryTimestamp[_tokenId] = _tokenRecoveryTimestamp;

    idToUri[_tokenId] = _uri;

    tokenLost[_tokenId] = false;
    
    arianeeWhitelist.addWhitelistedAddress(_tokenId, idToOwner[_tokenId]);

    if (_initialKeyIsRequestKey) {
      tokenAccess[_tokenId][1] = _encryptedInitialKey;
    }
    
    emit Hydrated(_tokenId, _imprint, _uri, _encryptedInitialKey, _tokenRecoveryTimestamp, _initialKeyIsRequestKey, _tokenCreation);
    
    return rewards[_tokenId];
    
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
    
    emit TokenRecovered(_tokenId);
  }
  
  /**
   * @dev Update a recovery request (doesn't transfer the NFT).
   * @notice Works only if called by the issuer.
   * @param _tokenId ID of the NFT to recover.
   * @param _active boolean to active or unactive the request.
   */
  function updateRecoveryRequest(uint256 _tokenId, bool _active) public whenNotPaused() isIssuer(_tokenId){
      recoveryRequest[_tokenId] = _active;
      
      emit RecoveryRequestUpdated(_tokenId, _active);
  }
  
  /**
   * @dev Valid a recovery request and transfer the NFT to the issuer.
   * @notice Works only if the request is active and if called by the owner of the contract.
   * @param _tokenId Id of the NFT to recover.
   */
  function validRecoveryRequest(uint256 _tokenId) public onlyOwner(){
      require(recoveryRequest[_tokenId]);
      idToApproval[_tokenId] = owner;
      _transferFrom(idToOwner[_tokenId], tokenIssuer[_tokenId], _tokenId);
      
      emit TokenRecovered(_tokenId);
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
    
    emit TokenURIUpdated(_tokenId, _uri);
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
  function addTokenAccess(uint256 _tokenId, bytes32 _encryptedTokenKey, bool _enable, uint8 _tokenType) external isOperator(_tokenId, msg.sender) whenNotPaused() {
    if (_enable) {
      tokenAccess[_tokenId][_tokenType] = _encryptedTokenKey;
    }
    else {
      tokenAccess[_tokenId][_tokenType] = 0x00;
    }
    
    emit tokenAccessAdded(_tokenId, _encryptedTokenKey, _enable, _tokenType);
  }

  /**
   * @dev Check if a token is requestable.
   * @param _tokenId uint256 ID of the token to check.
   * @return True if the NFT is requestable.
   */
  function isRequestable(uint256 _tokenId) public view returns (bool) {
    return tokenAccess[_tokenId][1] != 0x00;
  }

  /**
   * @dev Checks if NFT is requestable with the given token key.
   * @param _tokenId uint256 ID of the NFT to validate.
   * @param _tokenKey token key to check.
   */
  modifier canRequest(uint256 _tokenId, string memory _tokenKey) {
    require(isTokenValid(_tokenId, _tokenKey, 1));
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
   * @return total rewards of this NFT.
   */
  function requestToken(uint256 _tokenId, string memory _tokenKey, bool _keepRequestToken) public hasAbility(ABILITY_CREATE_ASSET) canRequest(_tokenId, _tokenKey) whenNotPaused() returns(uint256){
    idToApproval[_tokenId] = msg.sender;
    if(!_keepRequestToken){
        tokenAccess[_tokenId][1] = 0x00;    
    }
    _transferFrom(idToOwner[_tokenId], tx.origin, _tokenId);
    uint256 reward = rewards[_tokenId];
    delete rewards[_tokenId];
    return reward;
  }
  
  /**
   * @dev Legacy function of TransferFrom, add the new owner as whitelisted for the message.
   */
  
  function _transferFrom(address _to, address _from, uint256 _tokenId) internal {
      super._transferFrom(_to, _from, _tokenId);
      arianeeWhitelist.addWhitelistedAddress(_tokenId, _to);
  }

  
  /**
   * @dev Set a NFT as lost.
   * @param _tokenId  ID of the token to set lost.
   * @param _isLost Boolean to set the token lost or not.
   */
  function setTokenLost(uint256 _tokenId, bool _isLost) public whenNotPaused() isOperator(_tokenId, msg.sender) {
    tokenLost[_tokenId] = _isLost;
  }

}