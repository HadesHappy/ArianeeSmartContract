const ArianeeSmartAsset = artifacts.require('ArianeeSmartAsset');

contract("ArianeeSmartAsset", (accounts) => {
  beforeEach(async () => {
      smartAsset = await ArianeeSmartAsset.new();
    });

it('returns correct balanceOf after createFor', async () => {
    await smartAsset.createFor(accounts[0], "test");
    const count = await smartAsset.balanceOf(accounts[0]);
    assert.equal(count.toNumber(), 1);
  });



})