# Arianee Smart Contracts 

These smart contract define the Arianee Protocol.

Currently, there's two smart contracts.
- Smart Asset : ledger of all valuable items
- Identity : ledger of all arianee players


To be updated


# Arianee SmartAsset

This is a complete implementation of the [ERC-721](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md) non-fungible token standard for the Ethereum blockchain. This is an open source project build with [Truffle](http://truffleframework.com) framework.

Purpose of this implementation is to provide a good starting point for anyone who wants to use and develop non-fungible tokens on the Ethereum blockchain. Instead of re-implementing the ERC-721 yourself you can use this code which has gone through multiple audits and we hope it will be extensively used by the community in the future.

If you are looking for a more feature-rich and advanced ERC721 implementation, then check out the [Xcert repository](https://github.com/0xcert/ethereum-xcert).

## Structure

Since this is a Truffle project, you will find all tokens in `contracts/tokens/` directory. There are multiple implementations and you can select between:
- `ArianeeIdentity.sol`: This implements all methods for Arianee Identity
- `ArianeeSmartAsset.sol`: This is a contract hereted from the 0xCert ERC-721 implementation (https://github.com/0xcert/framework/blob/master/packages/0xcert-ethereum-erc721-contracts/src/contracts/nf-token-metadata-enumerable.sol). This implements all methods for creation, update and transfert of Arianee's Certificate.


## Requirements

* NodeJS 9.0+ recommended.
* Windows, Linux or Mac OS X.

**Using Remix?** This package uses NPM modules which are supported in the [Remix Alpha](https://remix-alpha.ethereum.org) version only. You can also use the `npm run flatten` command to create a `build/bundle.sol` file with all package contracts which you can manually copy and then paste into Remix editor.

## Installation

### Source

Clone the repository and install the required `npm` dependencies:

```
$ git clone git@github.com:Arianee/ArianeeSmartContract.git
$ cd ArianeeSmartContract
$ npm install
```

Make sure that everything has been set up correctly:

```
$ npm run test
```

To check if the contract run correctly in your environement, you can run truffle test:
```
ganache-cli --port 8546
truffle test
```

## Specification

```solidity
  pragma solidity ^0.5.1;
  
  interface ArianeeSmartContract{
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
      * @dev Reserve a NFT at the given ID.
      * @notice Can only be called by an authorized address.
      * @param _tokenId ID to reserve.
      * @param _to receiver of the token.
      * @param _rewards total rewards of this NFT.
      */
      function reserveToken(uint256 _tokenId, address _to, uint256 _rewards) public;
      
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
      function hydrateToken(uint256 _tokenId, bytes32 _imprint, string memory _uri, bytes32 _encryptedInitialKey, uint256 _tokenRecoveryTimestamp, bool _initialKeyIsRequestKey) public return(uint256);
        
      /**
       * @dev Recover the NFT to the issuer.
       * @notice Works only if called by the issuer and if called before the token Recovery Timestamp of the NFT.
       * @param _tokenId ID of the NFT to recover.
       */
       function recoverTokenToIssuer(uint256 _tokenId) public whenNotPaused() isIssuer(_tokenId);
          
     /**
      * @dev Update a recovery request (doesn't transfer the NFT).
      * @notice Works only if called by the issuer.
      * @param _tokenId ID of the NFT to recover.
      * @param _active boolean to active or unactive the request.
      */
      function updateRecoveryRequest(uint256 _tokenId, bool _active) public;
            
      /**
       * @dev Valid a recovery request and transfer the NFT to the issuer.
       * @notice Works only if the request is active and if called by the owner of the contract.
       * @param _tokenId Id of the NFT to recover.
       */
       function validRecoveryRequest(uint256 _tokenId) public;
      
      /**
       * @dev External function to update the tokenURI.
       * @notice Can only be called by the NFT's issuer.
       * @param _tokenId ID of the NFT to edit.
       * @param _uri New URI for the certificate.
       */
       function updateTokenURI(uint256 _tokenId, string calldata _uri) external;
      
      /**
       * @dev Add a token access to a NFT.
       * @notice can only be called by an NFT's operator.
       * @param _tokenId ID of the NFT.
       * @param _encryptedTokenKey Encoded token access to add.
       * @param _enable Enable or disable the token access.
       * @param _tokenType Type of token access (0=view, 1=service, 2=transfer).
       * @return true.
       */
       function addTokenAccess(uint256 _tokenId, bytes32 _encryptedTokenKey, bool _enable, uint8 _tokenType) external;
      
     /**
      * @dev Transfers the ownership of a NFT to another address
      * @notice Requires the msg sender to have the correct tokenKey and NFT has to be requestable.
      * Automatically approve the requester if _tokenKey is valid to allow transferFrom without removing ERC721 compliance.
      * @param _tokenId ID of the NFT to transfer.
      * @param _tokenKey String to encode to check transfer token access.
      * @param _keepRequestToken If false erase the access token of the NFT.
      * @return total rewards of this NFT.
      */
      function requestToken(uint256 _tokenId, string memory _tokenKey, bool _keepRequestToken) public;
    }
```

## Playground

We already deployed some contracts to [Sokol](https://blockscout.com/poa/sokol) network. You can play with them RIGHT NOW. No need to install software.

| Contract | Token address | Transaction hash
|-|-|-
| ArianeeIdentity | [0xb55c7377f4f902adc6088ef5941f7c7ec7f926e5](https://blockscout.com/poa/sokol/address/0xb55c7377f4f902adc6088ef5941f7c7ec7f926e5/transactions) | [0xc6af0aa1e8f4cbee78cd92cbfac80a3cc2e7b4051befe41e0aed7aa1623e1e47](https://blockscout.com/poa/sokol/tx/0xc6af0aa1e8f4cbee78cd92cbfac80a3cc2e7b4051befe41e0aed7aa1623e1e47/internal_transactions)
| ArianeeSmartAsset | [0x07a0af4d3a099e6d97955ef811132794cb686358](https://blockscout.com/poa/sokol/address/0x07a0af4d3a099e6d97955ef811132794cb686358/transactions) | [0xb75015adb96980af1af363e5cbd4a3056635b53cbb9b01d7b029a72c3423b2b6](https://blockscout.com/poa/sokol/tx/0xb75015adb96980af1af363e5cbd4a3056635b53cbb9b01d7b029a72c3423b2b6/internal_transactions)


## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for how to help out.

## Licence

See [LICENSE](./LICENSE) for details.
