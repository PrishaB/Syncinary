const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const fetch = require('node-fetch');
const { createPlaceRouter } = require('./places');

const place = { title: 'Hilton', address: 'New York', gps_coordinates: { latitude: 40.7, longitude: -74 } };

async function withServer(options, run) {
  const app = express();
  app.use('/places', createPlaceRouter(options));
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  try { await run(`http://127.0.0.1:${server.address().port}/places`); }
  finally { await new Promise(resolve => server.close(resolve)); }
}

test('[202-3] place search validates queries before calling the upstream', async () => {
  await withServer({ apiKey: '', fetchImpl: () => assert.fail('Unexpected upstream call') }, async url => {
    for (const query of ['', '?q=a', '?q=%20%20', '?q[]=Paris', `?q=${'a'.repeat(201)}`]) {
      assert.equal((await fetch(url + query)).status, 400);
    }
    assert.equal((await fetch(`${url}?q=Paris`)).status, 503);
  });
});

test('[202-2] place search returns only valid deduplicated coordinates and safe fields', async () => {
  await withServer({ apiKey: 'test-key', fetchImpl: async (url, options) => {
    const parsed = new URL(url);
    assert.equal(parsed.hostname, 'serpapi.com');
    assert.equal(parsed.searchParams.get('q'), 'Hilton New York');
    assert.equal(parsed.searchParams.get('engine'), 'google_maps');
    assert.equal(parsed.searchParams.get('api_key'), 'test-key');
    assert.equal(options.timeout, 10000);
    return { ok: true, json: async () => ({ local_results: [
      { ...place, secret: 'test-key' }, place, null, {},
      { ...place, gps_coordinates: { latitude: 91, longitude: 0 } },
      { ...place, gps_coordinates: { latitude: 0, longitude: 181 } },
      { ...place, gps_coordinates: { latitude: '40', longitude: 0 } },
    ] }) };
  } }, async url => {
    const response = await fetch(`${url}?q=%20Hilton%20New%20York%20`);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.deepEqual(await response.json(), { places: [{ name: 'Hilton', address: 'New York', latitude: 40.7, longitude: -74 }] });
  });
});

test('[202-2] single-place and empty searches are supported', async () => {
  for (const [data, count] of [[{ place_results: place }, 1], [{ local_results: [] }, 0]]) {
    await withServer({ apiKey: 'test-key', fetchImpl: async () => ({ ok: true, json: async () => data }) }, async url => {
      assert.equal((await (await fetch(`${url}?q=Hilton`)).json()).places.length, count);
    });
  }
});

test('[202-3] upstream failures never expose keys or raw errors', async () => {
  for (const fetchImpl of [
    async () => { throw new Error('private-key'); },
    async () => ({ ok: false }),
    async () => ({ ok: true, json: async () => ({ error: 'private-key' }) }),
    async () => ({ ok: true, json: async () => { throw new Error('private-key'); } }),
  ]) {
    await withServer({ apiKey: 'private-key', fetchImpl }, async url => {
      const response = await fetch(`${url}?q=Hilton`);
      assert.equal(response.status, 502);
      assert.ok(!(await response.text()).includes('private-key'));
    });
  }
});