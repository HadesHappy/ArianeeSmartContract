const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');
const catchRevert = require('./helpers/exceptions.js').catchRevert;

contract('ArianeeSmartAsset', (accounts) => {
  let smartAsset;
  beforeEach(async () => {
    smartAsset = await ArianeeSmartAsset.new();
  });

  it('shouldn\'t be able to reserve token without abilities', async()=>{
    await catchRevert(smartAsset.reserveToken(1,{from: accounts[0]}));
    const count = await smartAsset.balanceOf(accounts[0]);
    assert.equal(count.toNumber(), 0);
  });

  it('should returns correct balanceOf after createFor', async () => {
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.reserveToken(1,{from: accounts[0]});
    const count = await smartAsset.balanceOf(accounts[0]);
    assert.equal(count.toNumber(), 1);
  });

  it('should be able to hydrate NFT after reservation', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.reserveToken(1,{from: accounts[0]});
    
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), false);

    const tokenIssuer = await smartAsset.tokenIssuer(1);
    const encryptedInitialKey = await smartAsset.encryptedInitialKey(1);
    const tokenCreation = await smartAsset.tokenCreation(1);
    const idToImprint = await smartAsset.idToImprint(1);
    const idToUri = await smartAsset.idToUri(1);
    const tokenLost = await smartAsset.tokenLost(1);
    const tokenAccessRecovery = await smartAsset.tokenAccess(1,2);

    assert.equal(tokenIssuer, accounts[0], 'The issuers set in the NFT is not the issuer');
    assert.equal(encryptedInitialKey, web3.utils.keccak256('encryptedInitialKey'), 'The encryptedInitialKey, is not set correctly');
    assert.approximately(tokenCreation.toNumber(), Math.floor(Date.now()/1000), 3, 'The tokenCreation is not set correctly');
    assert.equal(idToImprint, web3.utils.keccak256('imprint'), 'The imprint is not set correctly');
    assert.equal(idToUri, 'http://arianee.org', 'The URI is not set correctly');
    assert.equal(tokenLost, false, 'The token Lost should be false by default');
    assert.equal(tokenAccessRecovery, false, 'The access Recovery should be false in this configuration');
  });

  it('shouldn\'t be able to hydrate a NFT without reserve it before', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    
    await catchRevert(smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), false));
  });

  it('shouldn\'t be able to reserve when the contract is paused', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.setPause(true);
    await catchRevert(smartAsset.reserveToken(1,{from: accounts[0]}));
    await catchRevert(smartAsset.reserveTokens(1,5,{from: accounts[0]}));
  });

  it('a new token with encrypted Key should be requestable', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.reserveToken(1,{from: accounts[0]});
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), true);

    const isRequestable = await smartAsset.isRequestable(1);
    assert.equal(isRequestable, true);
  });

  it('a new token create as requestable should be transferable', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.assignAbilities(accounts[1], [1]);
    await smartAsset.reserveToken(1,{from: accounts[0]});
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), true);

    await smartAsset.requestToken(1, 'encryptedInitialKey', false, {from:accounts[1]});
    const balanceAccount0 = await smartAsset.balanceOf(accounts[0]);
    const balanceAccount1 = await smartAsset.balanceOf(accounts[1]);
    assert.equal(balanceAccount0, 0);
    assert.equal(balanceAccount1, 1);
  });

  it('should not possible to make a token requestable if not approved', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.assignAbilities(accounts[1], [1]);
    await smartAsset.reserveToken(1, {from: accounts[0]});
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), false);

    await catchRevert(smartAsset.addTokenAccess(1, web3.utils.keccak256('encryptedInitialKey'), true, 2, {from:accounts[1]}));
    const isRequestable = await smartAsset.isRequestable(1);
    assert.equal(isRequestable, false);
  });

  it('a token should be requestable after added a token key ', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.assignAbilities(accounts[1], [1]);
    await smartAsset.reserveToken(1,{from: accounts[0]});
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), false);
    await smartAsset.addTokenAccess(1, web3.utils.keccak256('transferableKey'),true, 2);

    await smartAsset.requestToken(1, 'transferableKey', false, {from:accounts[1]});
    const balanceAccount0 = await smartAsset.balanceOf(accounts[0]);
    const balanceAccount1 = await smartAsset.balanceOf(accounts[1]);
    assert.equal(balanceAccount0, 0);
    assert.equal(balanceAccount1, 1);
  });

  it('a token shouldn\'t be requestable after a transfert', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.assignAbilities(accounts[1], [1]);
    await smartAsset.assignAbilities(accounts[2], [1]);
    await smartAsset.reserveToken(1,{from: accounts[0]});
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), false);
    await smartAsset.addTokenAccess(1, web3.utils.keccak256('transferableKey'),true, 2);

    await smartAsset.requestToken(1, 'transferableKey', false, {from:accounts[1]});
    await catchRevert(smartAsset.requestToken(1, 'transferableKey',false, {from:accounts[2]}));

    const balanceAccount1 = await smartAsset.balanceOf(accounts[1]);
    const balanceAccount2 = await smartAsset.balanceOf(accounts[2]);

    assert.equal(balanceAccount1, 1);
    assert.equal(balanceAccount2, 0);
  });

  it('a token should be requestable after transfert if specified', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.assignAbilities(accounts[1], [1]);
    await smartAsset.assignAbilities(accounts[2], [1]);
    await smartAsset.reserveToken(1,{from: accounts[0]});
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), false);
    await smartAsset.addTokenAccess(1, web3.utils.keccak256('transferableKey'),true, 2);

    await smartAsset.requestToken(1, 'transferableKey', true, {from:accounts[1]});
    await smartAsset.requestToken(1, 'transferableKey', false, {from:accounts[2]});

    const balanceAccount1 = await smartAsset.balanceOf(accounts[1]);
    const balanceAccount2 = await smartAsset.balanceOf(accounts[2]);

    assert.equal(balanceAccount1, 0);
    assert.equal(balanceAccount2, 1);
  });

  it('NFT should be recoverable before the tokenRecoveryTimestamp by the issuer', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.assignAbilities(accounts[1], [1]);
    await smartAsset.reserveToken(1, {from: accounts[0]});
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), true, {from: accounts[0]});

    await smartAsset.requestToken(1, 'encryptedInitialKey', false, {from:accounts[1]});
    await smartAsset.recoverTokenToIssuer(1, {from:accounts[0]});

    const balanceAccount0 = await smartAsset.balanceOf(accounts[0]);
    const balanceAccount1 = await smartAsset.balanceOf(accounts[1]);

    assert.equal(balanceAccount0, 1);
    assert.equal(balanceAccount1, 0);
  });

  it('NFT shouldn\'t be recoverable after the tokenRecoveryTimestamp', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.assignAbilities(accounts[1], [1]);
    await smartAsset.reserveToken(1, {from: accounts[0]});
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2), true, {from: accounts[0]});
    await smartAsset.requestToken(1, 'encryptedInitialKey', false, {from:accounts[1]});

    await setTimeout(async ()=>{
      await catchRevert(smartAsset.recoverTokenToIssuer(1, {from:accounts[0]}));
    },5000);

  });

  it('should be able to change URI if msg.sender=issuer even if issuer is not owner', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.assignAbilities(accounts[1], [1]);
    await smartAsset.reserveToken(1, {from: accounts[0]});
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), true);
    await smartAsset.requestToken(1, 'encryptedInitialKey', false, {from:accounts[1]});

    await smartAsset.updateTokenURI(1,'newURI');
    const uri = await smartAsset.idToUri(1);
    assert.equal(uri, 'newURI');

  });

  it('should be viewable after set token 0', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.reserveToken(1,{from: accounts[0]});
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), false);
    await smartAsset.addTokenAccess(1, web3.utils.keccak256('serviceKey'),true, 0);

    const isview = await smartAsset.isView(1);
    assert.equal(isview, true);

  });

  it('should be service after set token 1', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.reserveToken(1,{from: accounts[0]});
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), false);
    await smartAsset.addTokenAccess(1, web3.utils.keccak256('serviceKey'),true, 1);

    const isService= await smartAsset.isService(1);
    assert.equal(isService, true);

    await smartAsset.serviceFrom(accounts[3],1,'serviceKey', 'serviceType', 'service Description');
  });

  it('shouldn\'t be able to service after service is done', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.reserveToken(1,{from: accounts[0]});
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), false);
    await smartAsset.addTokenAccess(1, web3.utils.keccak256('serviceKey'),true, 1);
    await smartAsset.serviceFrom(accounts[3],1,'serviceKey', 'serviceType', 'service Description');

    const isService= await smartAsset.isService(1);
    assert.equal(isService, false);
  });

  it('should be set as lost when operator set it as lost', async()=>{
    await smartAsset.assignAbilities(accounts[0], [1]);
    await smartAsset.reserveToken(1,{from: accounts[0]});
    await smartAsset.hydrateToken(1, web3.utils.keccak256('imprint'), 'http://arianee.org', web3.utils.keccak256('encryptedInitialKey'), (Math.floor((Date.now())/1000)+2678400), false);

    await smartAsset.setTokenLost(1,true);
    const tokenLost = await smartAsset.tokenLost(1);
    assert.equal(tokenLost, true);

  });

});