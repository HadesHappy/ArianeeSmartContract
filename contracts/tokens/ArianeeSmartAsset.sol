pragma solidity 0.5.1;

import "@0xcert/ethereum-utils-contracts/src/contracts/permission/abilitable.sol";
import "@0xcert/ethereum-utils-contracts/src/contracts/permission/ownable.sol";
import "./Pausable.sol";

import "@0xcert/ethereum-erc721-contracts/src/contracts/nf-token-metadata-enumerable.sol";

contract ArianeeWhitelist {
  function addWhitelistedAddress(uint256 _tokenId, address _address) public;
}

contract ArianeeStore{
    function canTransfer(address _to,address _from,uint256 _tokenId) public returns(bool);
}

contract ArianeeSmartAsset is
NFTokenMetadataEnumerable,
Abilitable,
Ownable,
Pausable
{

  /**
   * @dev Mapping from token id to URI.
   */
  mapping(uint256 => string) internal idToUri;

  /**
   * @dev Mapping from token id to Token Access (0=view, 1=transfer).
   */
  mapping(uint256 => mapping(uint256 => bytes32)) internal tokenAccess;

  /**
   * @dev Mapping from token id to TokenImprintUpdate.
   */
  mapping(uint256 => bytes32) internal idToImprint;

  /**
   * @dev Mapping from token id to recovery request bool. 
   */
  mapping(uint256=>bool) internal recoveryRequest;

  /**
   * @dev Mapping from token id to total rewards for this NFT.
   */
  mapping(uint256=>uint256) internal rewards;
  
  /**
   * @dev Mapping from token id to Cert.
   */
  mapping(uint256 => Cert) internal certificate;
  
  /**
   * @dev This emits when a new address is set.
   */
  event SetAddress(string _addressType, address _newAddress);
  
  struct Cert {
      address tokenIssuer;
      uint256 tokenCreationDate;
      uint256 tokenRecoveryTimestamp;
  }
  
  
  /**
   * @dev Ability to create and hydrate NFT.
   */
  uint8 constant ABILITY_CREATE_ASSET = 2;

  /**
   * @dev Error constants.
   */
  string constant CAPABILITY_NOT_SUPPORTED = "007001";
  string constant TRANSFERS_DISABLED = "007002";
  string constant NOT_VALID_XCERT = "007003";
  string constant NFT_ALREADY_SET = "007006";
  string constant NOT_OWNER_OR_OPERATOR = "007004";

  /**
   * Interface for all the connected contracts.
   */
  ArianeeWhitelist arianeeWhitelist;
  ArianeeStore store;

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
  event tokenAccessAdded(uint256 _tokenId, bytes32 _encryptedTokenKey, bool _enable, uint256 _tokenType);


  /**
   * @dev Check if the msg.sender can operate the NFT.
   * @param _tokenId ID of the NFT to test.
   * @param _operator Address to test.
   */
  modifier isOperator(uint256 _tokenId, address _operator) {
    require(canOperate(_tokenId, _operator), NOT_OWNER_OR_OPERATOR);
    _;
  }

  /**
   * @dev Check if an operator is valid for a given NFT.
   * @param _tokenId nft to check.
   * @param _operator operator to check.
   * @return true if operator is valid.
   */
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
   * @dev Change address of the store infrastructure.
   * @param _storeAddress new address of the store.
   */
   function setStoreAddress(address _storeAddress) public onlyOwner(){
      store = ArianeeStore(address(_storeAddress));
      emit SetAddress("storeAddress", _storeAddress);
   }

  /**
   * @dev Reserve a NFT at the given ID.
   * @notice Has to be called through an authorized contract.
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
   * @notice Has to be called through an authorized contract.
   * @notice Can only be called once and by an NFT's operator.
   * @param _tokenId ID of the NFT to modify.
   * @param _imprint Proof of the certification.
   * @param _uri URI of the JSON certification.
   * @param _encryptedInitialKey Initial encrypted key.
   * @param _tokenRecoveryTimestamp Limit date for the issuer to be able to transfer back the NFT.
   * @param _initialKeyIsRequestKey If true set initial key as request key.
   */
  function hydrateToken(uint256 _tokenId, bytes32 _imprint, string memory _uri, bytes32 _encryptedInitialKey, uint256 _tokenRecoveryTimestamp, bool _initialKeyIsRequestKey) public hasAbility(ABILITY_CREATE_ASSET) whenNotPaused() isOperator(_tokenId, tx.origin) returns(uint256){
    require(!(certificate[_tokenId].tokenCreationDate > 0), NFT_ALREADY_SET);
    uint256 _tokenCreation = block.timestamp;
    tokenAccess[_tokenId][0] = _encryptedInitialKey;
    idToImprint[_tokenId] = _imprint;
    idToUri[_tokenId] = _uri;
    
    arianeeWhitelist.addWhitelistedAddress(_tokenId, idToOwner[_tokenId]);

    if (_initialKeyIsRequestKey) {
      tokenAccess[_tokenId][1] = _encryptedInitialKey;
    }
    
    Cert memory _cert = Cert({
             tokenIssuer : idToOwner[_tokenId],
             tokenCreationDate: _tokenCreation,
             tokenRecoveryTimestamp :_tokenRecoveryTimestamp
            });
            
    certificate[_tokenId] = _cert;

    emit Hydrated(_tokenId, _imprint, _uri, _encryptedInitialKey, _tokenRecoveryTimestamp, _initialKeyIsRequestKey, _tokenCreation);

    return rewards[_tokenId];
  }

  /**
   * @dev Recover the NFT to the issuer.
   * @notice Works only if called by the issuer and if called before the token Recovery Timestamp of the NFT.
   * @param _tokenId ID of the NFT to recover.
   */
  function recoverTokenToIssuer(uint256 _tokenId) public whenNotPaused() isIssuer(_tokenId) {
    require(block.timestamp < certificate[_tokenId].tokenRecoveryTimestamp);
    idToApproval[_tokenId] = certificate[_tokenId].tokenIssuer;
    _transferFrom(idToOwner[_tokenId], certificate[_tokenId].tokenIssuer, _tokenId);

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
    recoveryRequest[_tokenId] = false;
    
    idToApproval[_tokenId] = owner;
    _transferFrom(idToOwner[_tokenId], certificate[_tokenId].tokenIssuer, _tokenId);

    emit RecoveryRequestUpdated(_tokenId, false);
    emit TokenRecovered(_tokenId);
  }

  /**
  * @dev Check if msg.sender is the issuer of a NFT.
  * @param _tokenId ID of the NFT to test.
  */
  modifier isIssuer(uint256 _tokenId) {
    require(msg.sender == certificate[_tokenId].tokenIssuer);
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
      if(bytes(idToUri[_tokenId]).length > 0){
        return idToUri[_tokenId];
      }
      else{
          return string(abi.encodePacked(uriBase, _uint2str(_tokenId)));
      }
    
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
  function addTokenAccess(uint256 _tokenId, bytes32 _encryptedTokenKey, bool _enable, uint256 _tokenType) external isOperator(_tokenId, msg.sender) whenNotPaused() {
      require(_tokenType>0);
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
  function isTokenValid(uint256 _tokenId, string memory _tokenKey, uint256 _tokenType) public view returns (bool){
    return tokenAccess[_tokenId][_tokenType] != 0x00 && keccak256(abi.encodePacked(_tokenKey)) == tokenAccess[_tokenId][_tokenType];
  }

  /**
   * @dev Transfers the ownership of a NFT to another address
   * @notice Requires to send the correct tokenKey and the NFT has to be requestable
   * @notice Has to be called through an authorized contract.
   * @notice Automatically approve the requester if _tokenKey is valid to allow transferFrom without removing ERC721 compliance.
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
   * @notice Require the store to approve the transfer.
   */
  function _transferFrom(address _to, address _from, uint256 _tokenId) internal {
    require(store.canTransfer(_to, _from, _tokenId));
    super._transferFrom(_to, _from, _tokenId);
    arianeeWhitelist.addWhitelistedAddress(_tokenId, _to);
  }
  
   /**
   * @notice The issuer address for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT. 
   * @param _tokenId Id for which we want the issuer.
   * @return Issuer address of _tokenId.
   */
  function issuerOf(uint256 _tokenId) external view returns(address _tokenIssuer){
      require(idToOwner[_tokenId] != address(0), NOT_VALID_NFT);
      _tokenIssuer = certificate[_tokenId].tokenIssuer;
  }
  
   /**
   * @notice The imprint for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT. 
   * @param _tokenId Id for which we want the imprint.
   * @return Imprint address of _tokenId.
   */
  function tokenImprint(uint256 _tokenId) external view returns(bytes32 _imprint){
      require(idToOwner[_tokenId] != address(0), NOT_VALID_NFT);
      _imprint = idToImprint[_tokenId];
  }
  
  
  /**
   * @notice The creation date for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT. 
   * @param _tokenId Id for which we want the creation date.
   * @return Creation date of _tokenId.
   */
  function tokenCreation(uint256 _tokenId) external view returns(uint256 _tokenCreation){
      require(idToOwner[_tokenId] != address(0), NOT_VALID_NFT);
      _tokenCreation = certificate[_tokenId].tokenCreationDate;
  }
  
  /**
   * @notice The Token Access for a given Token ID and token type.
   * @dev Throws if `_tokenId` is not a valid NFT. 
   * @param _tokenId Id for which we want the token access.
   * @param _tokenType for which we want the token access.
   * @return Token access of _tokenId.
   */
  function tokenHashedAccess(uint256 _tokenId, uint256 _tokenType) external view returns(bytes32 _tokenAccess){
      require(idToOwner[_tokenId] != address(0), NOT_VALID_NFT);
      _tokenAccess = tokenAccess[_tokenId][_tokenType];
  }
  
  /**
   * @notice The recovery timestamp for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT. 
   * @param _tokenId Id for which we want the recovery timestamp.
   * @return Recovery timestamp of _tokenId.
   */
  function tokenRecoveryDate(uint256 _tokenId) external view returns(uint256 _tokenRecoveryTimestamp){
      require(idToOwner[_tokenId] != address(0), NOT_VALID_NFT);
      _tokenRecoveryTimestamp = certificate[_tokenId].tokenRecoveryTimestamp;
  }
  
  /**
   * @notice The recovery timestamp for a given Token ID.
   * @dev Throws if `_tokenId` is not a valid NFT. 
   * @param _tokenId Id for which we want the recovery timestamp.
   * @return Recovery timestamp of _tokenId.
   */
  function recoveryRequestOpen(uint256 _tokenId) external view returns(bool _recoveryRequest){
      require(idToOwner[_tokenId] != address(0), NOT_VALID_NFT);
      _recoveryRequest = recoveryRequest[_tokenId];
  }  
  

}

