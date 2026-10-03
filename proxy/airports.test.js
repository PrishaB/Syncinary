const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const fetch = require('node-fetch');
const { createAirportRouter, resolveAirport } = require('./airports');

const airport = { code: 'IND', name: 'Indianapolis International Airport', city: 'Indianapolis', latitude: 39.7173, longitude: -86.2944 };
const place = { types: ['airport'], displayName: { text: airport.name }, location: { latitude: airport.latitude, longitude: airport.longitude } };

test('resolves a matching airport but rejects missing, distant, ambiguous and mismatched places', () => {
  assert.equal(resolveAirport(place, [airport]).code, 'IND');
  assert.equal(resolveAirport({ ...place, location: undefined }, [airport]), null);
  assert.equal(resolveAirport({ ...place, types: ['locality'] }, [airport]), null);
  assert.equal(resolveAirport({ ...place, location: { latitude: 0, longitude: 0 } }, [airport]), null);
  assert.equal(resolveAirport(place, [airport, { ...airport, code: 'AAA' }]), null);
  assert.equal(resolveAirport({ ...place, displayName: { text: 'Unrelated Airfield' } }, [airport]), null);
  assert.equal(resolveAirport({ ...place, displayName: { text: 'Airport' } }, [airport]), null);
  assert.equal(resolveAirport({ ...place, displayName: { text: 'Heathrow Airport' } },
    [{ ...airport, code: 'LHR', name: 'London Heathrow Airport' }]).code, 'LHR');
});

async function withServer(options, run) {
  const app = express();
  app.use('/airports', createAirportRouter({ catalog: [airport], ...options }));
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  try { await run(`http://127.0.0.1:${server.address().port}/airports`); }
  finally { await new Promise(resolve => server.close(resolve)); }
}

test('validates query, resolves known codes without Google, and reports missing configuration', async () => {
  await withServer({ apiKey: '' }, async url => {
    assert.equal((await fetch(`${url}?q=a`)).status, 400);
    const response = await fetch(`${url}?q=ind`);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.equal((await response.json()).airports[0].code, 'IND');
    assert.equal((await fetch(`${url}?q=Indianapolis`)).status, 503);
  });
});

test('requests airport-only Google results, filters unresolved entries and deduplicates codes', async () => {
  await withServer({ apiKey: 'test-key', fetchImpl: async (url, options) => {
    assert.equal(url, 'https://places.googleapis.com/v1/places:searchText');
    assert.equal(options.headers['X-Goog-Api-Key'], 'test-key');
    assert.equal(JSON.parse(options.body).strictTypeFiltering, true);
    assert.equal(JSON.parse(options.body).includedType, 'airport');
    return { ok: true, json: async () => ({ places: [place, place, { ...place, types: ['locality'] }] }) };
  } }, async url => {
    const data = await (await fetch(`${url}?q=Indianapolis`)).json();
    assert.equal(data.source, 'Google Maps');
    assert.deepEqual(data.airports.map(a => a.code), ['IND']);
  });
});

test('does not expose upstream errors or secrets', async () => {
  await withServer({ apiKey: 'secret-key', fetchImpl: async () => { throw new Error('secret-key'); } }, async url => {
    const response = await fetch(`${url}?q=Indianapolis`);
    assert.equal(response.status, 502);
    assert.ok(!(await response.text()).includes('secret-key'));
  });
});
