const ArianeeIdentity = artifacts.require('ArianeeIdentity');
const catchRevert = require('./helpers/exceptions.js').catchRevert;

contract('ArianeeIdentity', (accounts) => {
  let identity;
  beforeEach(async () => {
    identity = await ArianeeIdentity.new();
  });

  it('owner should be able to add an identity in whitelist', async()=>{
    const isWhitelistedBefore = await identity.whitelist(accounts[1]);
    await identity.addAddressTowhitelist(accounts[1]);
    const isWhitelisted = await identity.whitelist(accounts[1]);

    assert.equal(isWhitelistedBefore, false);
    assert.equal(isWhitelisted, true);
  });

  it('a whitelisted address should be able to update his information', async()=>{
    await identity.addAddressTowhitelist(accounts[1]);
    await identity.updateInformations('uri', web3.utils.keccak256('imprint'), {from: accounts[1]});

    const tokenURI = await identity.tokenURI(accounts[1]);
    const addressToImprint = await identity.addressToImprint(accounts[1]);

    assert.equal(tokenURI, 'uri');
    assert.equal(addressToImprint, web3.utils.keccak256('imprint'));

  });

  it('should be possible for the owner to add a compromise date', async()=>{
    const date = Math.round(Date.now()/1000);
    await identity.updateCompromiseDate(accounts[1], date);
    const compromiseDate = await identity.compromiseDate(accounts[1]);
    assert.equal(compromiseDate, date);
  });

  it('shouldn\'t be possible for a non whitelisted to update his information', async()=>{
    await catchRevert(identity.updateInformations('uri', web3.utils.keccak256('imprint'), {from: accounts[1]}));
  });

  it('only owner should be allowed to add a compromise date', async()=>{
    await catchRevert(identity.updateCompromiseDate(accounts[1], Math.round(Date.now()/1000), {from:accounts[2]}));
  });

});