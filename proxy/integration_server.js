
process.env.SERPAPI_KEY = 'integration-test-key';

const { app, setFlightFetch } = require('./server');

setFlightFetch(async (url) => {
  const origin = new URL(url).searchParams.get('departure_id');

  if (origin === 'ERR') {
    throw new Error('Simulated SerpApi failure');
  }

  if (origin === 'EMPTY') {
    return {
      json: async () => ({
        best_flights: [],
        other_flights: [],
      }),
    };
  }

  return {
    json: async () => ({
      best_flights: [
        {
          price: 350,
          total_duration: 240,
          booking_token: 'test-token',
          flights: [
            {
              airline: 'Test Airline',
              departure_airport: {
                id: 'ORD',
                time: '2026-12-10 08:00',
              },
              arrival_airport: {
                id: 'SFO',
                time: '2026-12-10 12:00',
              },
            },
          ],
        },
      ],
    }),
  };
});

app.listen(3000, '127.0.0.1', () => {
  console.log('Integration test proxy running on port 3000');
});
