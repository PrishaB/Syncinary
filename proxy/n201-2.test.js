
// N201-2: Verify that 50 back-to-back proxy requests complete reliably.
// Run from proxy/: node --test n201-2.test.js
// SerpApi is mocked, so no API credits or real network access are needed.
const test = require('node:test');
const assert = require('node:assert/strict');
const { performance } = require('node:perf_hooks');

process.env.SERPAPI_KEY = 'test-serpapi-key';

const { app, setFlightFetch, resetFlightFetch } = require('./server');

const REQUEST_COUNT = 50;
const SEARCH_PATH =
  '/flights?origin=ORD&destination=LAX&departureDate=2026-12-10&adults=1';

// Share one temporary HTTP server across the requests in each test.
// Opening a new server for every request would distort timing measurements.
async function withServer(run) {
  const server = app.listen(0, '127.0.0.1');

  try {
    if (!server.listening) {
      await new Promise((resolve, reject) => {
        server.once('listening', resolve);
        server.once('error', reject);
      });
    }

    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    return await run(baseUrl);
  } finally {
    // Close connections cleanly even if an assertion or fetch fails.
    await new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
    resetFlightFetch();
  }
}

// Measure one complete HTTP request, including JSON parsing.
async function timedRequest(baseUrl, path = SEARCH_PATH) {
  const start = performance.now();
  const response = await fetch(`${baseUrl}${path}`);
  const body = await response.json();

  return {
    status: response.status,
    body,
    durationMs: performance.now() - start,
  };
}

// Record useful performance evidence instead of relying on hard-coded
// timing limits that vary significantly by developer machine or CI runner.
function summarizeTimings(timings) {
  const sorted = [...timings].sort((a, b) => a - b);
  const total = timings.reduce((sum, ms) => sum + ms, 0);
  const p95Index = Math.ceil(sorted.length * 0.95) - 1;

  return {
    count: timings.length,
    averageMs: Number((total / timings.length).toFixed(2)),
    maxMs: Number(sorted[sorted.length - 1].toFixed(2)),
    p95Ms: Number(sorted[p95Index].toFixed(2)),
  };
}

test('N201-2: 50 back-to-back flight searches succeed', async () => {
  const expectedFlights = [
    {
      price: 250,
      flights: [
        { departure_airport: { id: 'ORD' }, arrival_airport: { id: 'LAX' } },
      ],
    },
  ];
  let upstreamCalls = 0;

  // Return a deterministic successful response for every SerpApi call.
  setFlightFetch(async () => {
    upstreamCalls += 1;
    return { json: async () => ({ best_flights: expectedFlights }) };
  });

  await withServer(async (baseUrl) => {
    const timings = [];
    let successCount = 0;
    let failureCount = 0;

    // Await each request before sending the next: sequential, not concurrent.
    for (let i = 0; i < REQUEST_COUNT; i++) {
      const result = await timedRequest(baseUrl);
      timings.push(result.durationMs);

      if (result.status === 200) successCount++;
      else failureCount++;

      assert.equal(result.status, 200, `Request ${i + 1} failed`);
      assert.deepEqual(result.body, expectedFlights);
      assert.ok(Number.isFinite(result.durationMs));
      assert.ok(result.durationMs >= 0);
    }

    assert.equal(successCount, 50);
    assert.equal(failureCount, 0);
    assert.equal(upstreamCalls, 50, 'All searches should reach the upstream mock');

    const metrics = summarizeTimings(timings);
    assert.equal(metrics.count, 50);
    console.log('N201-2 consecutive requests:', metrics);

    // Verify the proxy remains responsive immediately after the burst.
    const recovery = await timedRequest(baseUrl);
    assert.equal(recovery.status, 200);
    assert.deepEqual(recovery.body, expectedFlights);
    assert.equal(upstreamCalls, 51);
  });
});

test('N201-2: proxy handles a failed upstream call during a 50-request burst', async () => {
  let upstreamCalls = 0;
  const failureAt = 25;

  setFlightFetch(async () => {
    upstreamCalls += 1;
    if (upstreamCalls === failureAt) {
      throw new Error('Simulated upstream interruption');
    }
    return { json: async () => ({ best_flights: [{ price: 300 }] }) };
  });

  await withServer(async (baseUrl) => {
    const timings = [];
    let successCount = 0;
    let errorCount = 0;

    for (let i = 1; i <= REQUEST_COUNT; i++) {
      const result = await timedRequest(baseUrl);
      timings.push(result.durationMs);

      if (i === failureAt) {
        assert.equal(result.status, 500);
        assert.equal(
          result.body.error,
          'Unable to complete the search. Please try again later.'
        );
        errorCount++;
      } else {
        assert.equal(result.status, 200, `Request ${i} should recover`);
        assert.deepEqual(result.body, [{ price: 300 }]);
        successCount++;
      }
    }

    assert.equal(successCount, 49);
    assert.equal(errorCount, 1);
    assert.equal(upstreamCalls, 50);
    console.log('N201-2 injected-failure requests:', summarizeTimings(timings));

    // The server should still work after a failed upstream request.
    const recovery = await timedRequest(baseUrl);
    assert.equal(recovery.status, 200);
    assert.deepEqual(recovery.body, [{ price: 300 }]);
    assert.equal(upstreamCalls, 51);
  });
});
