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
