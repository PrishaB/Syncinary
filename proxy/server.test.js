const test = require('node:test');
const assert = require('node:assert/strict');

process.env.SERPAPI_KEY = 'test-serpapi-key';

const {
  app,
  setFlightFetch,
  resetFlightFetch,
} = require('./server');

// Starts the Express app on a temporary port for a single request.
// Port 0 tells Node to choose an available port automatically.
async function request(path) {
  const server = app.listen(0);

  try {
    await new Promise((resolve) => {
      if (server.listening) {
        resolve();
      } else {
        server.once('listening', resolve);
      }
    });

    const address = server.address();

    const response = await fetch(
      `http://127.0.0.1:${address.port}${path}`
    );

    const body = await response.json();

    return {
      status: response.status,
      body,
    };
  } finally {
    await new Promise((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
        } else {
          resolve();
        }
      });
    });
  }
}

test.afterEach(() => {
  resetFlightFetch();
});

test('GET /flights returns best_flights when available', async () => {
  const bestFlights = [
    {
      price: 250,
      flights: [{ departure_airport: { id: 'ORD' } }],
    },
  ];

  setFlightFetch(async () => ({
    json: async () => ({
      best_flights: bestFlights,
      other_flights: [{ price: 500 }],
    }),
  }));

  const response = await request(
    '/flights?origin=ORD&destination=LAX&departureDate=2026-12-10&adults=1'
  );

  assert.equal(response.status, 200);
  assert.deepEqual(response.body, bestFlights);
});

test('GET /flights falls back to other_flights when best_flights is missing', async () => {
  const otherFlights = [
    {
      price: 300,
      flights: [{ departure_airport: { id: 'ORD' } }],
    },
  ];

  setFlightFetch(async () => ({
    json: async () => ({
      other_flights: otherFlights,
    }),
  }));

  const response = await request(
    '/flights?origin=ORD&destination=LAX&departureDate=2026-12-10&adults=1'
  );

  assert.equal(response.status, 200);
  assert.deepEqual(response.body, otherFlights);
});

test('GET /flights falls back to other_flights when best_flights is empty', async () => {
  const otherFlights = [
    {
      price: 325,
      flights: [{ departure_airport: { id: 'ORD' } }],
    },
  ];

  setFlightFetch(async () => ({
    json: async () => ({
      best_flights: [],
      other_flights: otherFlights,
    }),
  }));

  const response = await request(
    '/flights?origin=ORD&destination=LAX&departureDate=2026-12-10&adults=1'
  );

  assert.equal(response.status, 200);
  assert.deepEqual(response.body, otherFlights);
});

test('GET /flights returns an empty array when no flights are available', async () => {
  setFlightFetch(async () => ({
    json: async () => ({}),
  }));

  const response = await request(
    '/flights?origin=ORD&destination=LAX&departureDate=2026-12-10&adults=1'
  );

  assert.equal(response.status, 200);
  assert.deepEqual(response.body, []);
});

test('GET /flights returns 500 when SerpApi request fails', async () => {
  setFlightFetch(async () => {
    throw new Error('Upstream request failed');
  });

  const response = await request(
    '/flights?origin=ORD&destination=LAX&departureDate=2026-12-10&adults=1'
  );

  assert.equal(response.status, 500);
  assert.equal(response.body.error, 'Upstream request failed');
});

test('GET /flights error response does not expose the SerpApi key', async () => {
  setFlightFetch(async () => {
    throw new Error('Upstream request failed');
  });

  const response = await request(
    '/flights?origin=ORD&destination=LAX&departureDate=2026-12-10&adults=1'
  );

  const responseText = JSON.stringify(response.body);

  assert.equal(response.status, 500);
  assert.equal(
    responseText.includes('test-serpapi-key'),
    false
  );
});

test('GET /flights sends correct query parameters to SerpApi', async () => {
  let requestedUrl;

  setFlightFetch(async (url) => {
    requestedUrl = new URL(url);

    return {
      json: async () => ({
        best_flights: [],
      }),
    };
  });

  const response = await request(
    '/flights?origin=ORD&destination=LAX&departureDate=2026-12-10&adults=2'
  );

  assert.equal(response.status, 200);

  assert.equal(
    requestedUrl.searchParams.get('engine'),
    'google_flights'
  );

  assert.equal(
    requestedUrl.searchParams.get('departure_id'),
    'ORD'
  );

  assert.equal(
    requestedUrl.searchParams.get('arrival_id'),
    'LAX'
  );

  assert.equal(
    requestedUrl.searchParams.get('outbound_date'),
    '2026-12-10'
  );

  assert.equal(
    requestedUrl.searchParams.get('adults'),
    '2'
  );

  assert.equal(
    requestedUrl.searchParams.get('type'),
    '2'
  );
});

test('GET /flights defaults adults to 1 when adults is not supplied', async () => {
  let requestedUrl;

  setFlightFetch(async (url) => {
    requestedUrl = new URL(url);

    return {
      json: async () => ({
        best_flights: [],
      }),
    };
  });

  const response = await request(
    '/flights?origin=ORD&destination=LAX&departureDate=2026-12-10'
  );

  assert.equal(response.status, 200);

  assert.equal(
    requestedUrl.searchParams.get('adults'),
    '1'
  );
});

test('GET /flights uses type 2 for a one-way flight', async () => {
  let requestedUrl;

  setFlightFetch(async (url) => {
    requestedUrl = new URL(url);

    return {
      json: async () => ({
        best_flights: [],
      }),
    };
  });

  const response = await request(
    '/flights?origin=ORD&destination=LAX&departureDate=2026-12-10'
  );

  assert.equal(response.status, 200);

  assert.equal(
    requestedUrl.searchParams.get('type'),
    '2'
  );

  assert.equal(
    requestedUrl.searchParams.has('return_date'),
    false
  );
});

test('GET /flights uses type 1 and return_date for a round trip', async () => {
  let requestedUrl;

  setFlightFetch(async (url) => {
    requestedUrl = new URL(url);

    return {
      json: async () => ({
        best_flights: [],
      }),
    };
  });

  const response = await request(
    '/flights?origin=ORD&destination=LAX&departureDate=2026-12-10&returnDate=2026-12-20'
  );

  assert.equal(response.status, 200);

  assert.equal(
    requestedUrl.searchParams.get('type'),
    '1'
  );

  assert.equal(
    requestedUrl.searchParams.get('return_date'),
    '2026-12-20'
  );
});

test('GET /flights returns 400 when origin is missing', async () => {
  const response = await request(
    '/flights?destination=LAX&departureDate=2026-12-10'
  );

  assert.equal(response.status, 400);

  assert.equal(
    response.body.error,
    'origin, destination, and departureDate are required'
  );
});

test('GET /flights returns 400 when origin is empty', async () => {
  const response = await request(
    '/flights?origin=&destination=LAX&departureDate=2026-12-10'
  );

  assert.equal(response.status, 400);
});

test('GET /flights returns 400 when destination is missing', async () => {
  const response = await request(
    '/flights?origin=ORD&departureDate=2026-12-10'
  );

  assert.equal(response.status, 400);
});

test('GET /flights returns 400 when destination is empty', async () => {
  const response = await request(
    '/flights?origin=ORD&destination=&departureDate=2026-12-10'
  );

  assert.equal(response.status, 400);
});

test('GET /flights returns 400 when departureDate is missing', async () => {
  const response = await request(
    '/flights?origin=ORD&destination=LAX'
  );

  assert.equal(response.status, 400);
});

test('GET /flights returns 400 when departureDate is empty', async () => {
  const response = await request(
    '/flights?origin=ORD&destination=LAX&departureDate='
  );

  assert.equal(response.status, 400);
});

test('GET /flights returns 400 when adults is non-numeric', async () => {
  const response = await request(
    '/flights?origin=ORD&destination=LAX&departureDate=2026-12-10&adults=abc'
  );

  assert.equal(response.status, 400);

  assert.equal(
    response.body.error,
    'adults must be numeric'
  );
});