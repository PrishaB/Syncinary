const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Load the real route handlers with a stubbed upstream and no listening socket.
function loadRoutes(fetchImpl) {
  const routes = new Map();
  const app = { use() {}, get: (route, handler) => routes.set(route, handler), listen() {} };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, 'server.js'), 'utf8'), {
    require: name => {
      if (name === 'express') return () => app;
      if (name === 'node-fetch') return fetchImpl;
      return require(name);
    },
    process: { env: { SERPAPI_KEY: 'test-secret' } },
    URL,
    console,
  });
  return routes;
}

const query = {
  origin: 'IND', destination: 'LAX', departureDate: '2027-01-01',
  returnDate: '2027-01-08', departureToken: 'departure', bookingToken: 'booking',
  location: 'Los Angeles', checkInDate: '2027-01-01', checkOutDate: '2027-01-08',
};
const routePaths = ['/flights', '/flights/return', '/flights/booking', '/hotels'];

async function invoke(handler) {
  const response = {
    statusCode: 200,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = JSON.parse(JSON.stringify(body)); },
  };
  await handler({ query }, response);
  return response;
}

for (const failure of ['fetch', 'json']) {
  for (const route of routePaths) {
    test(`[201-5] ${route} hides upstream URLs and keys on ${failure} failure`, async () => {
      const routes = loadRoutes(async url => {
        assert.equal(new URL(url).searchParams.get('api_key'), 'test-secret');
        const fail = () => { throw new Error(`request to ${url} failed: test-secret`); };
        if (failure === 'fetch') fail();
        return { json: fail };
      });
      const response = await invoke(routes.get(route));
      assert.equal(response.statusCode, 500);
      assert.deepEqual(response.body, {
        error: 'Unable to complete the search. Please try again later.',
      });
    });
  }
}

test('[201-5] successful SerpApi responses preserve result arrays and flight fallback', async () => {
  for (const data of [
    { best_flights: [{ id: 'best' }], other_flights: [{ id: 'other' }], booking_options: [{ id: 'booking' }], properties: [{ id: 'hotel' }] },
    { other_flights: [{ id: 'fallback' }] },
    { best_flights: [], other_flights: [{ id: 'other' }] },
    {},
  ]) {
    const routes = loadRoutes(async () => ({ json: async () => data }));
    for (const route of routePaths) {
      const response = await invoke(routes.get(route));
      const expected = route === '/hotels' ? data.properties ?? []
        : route === '/flights/booking' ? data.booking_options ?? []
          : data.best_flights ?? data.other_flights ?? [];
      assert.equal(response.statusCode, 200);
      assert.deepEqual(response.body, expected);
    }
  }
});
