const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');

const app = express();
app.use(cors());

const SERPAPI_KEY = process.env.SERPAPI_KEY;
if (!SERPAPI_KEY) {
  console.error(
    'Missing SERPAPI_KEY. Set it in the environment (see proxy/.env.example) before starting the proxy.'
  );
  process.exit(1);
}

app.get('/flights', async (req, res) => {
  const { origin, destination, departureDate, adults } = req.query;
  const url = new URL('https://serpapi.com/search');
  url.searchParams.set('engine', 'google_flights');
  url.searchParams.set('departure_id', origin);
  url.searchParams.set('arrival_id', destination);
  url.searchParams.set('outbound_date', departureDate);
  url.searchParams.set('adults', adults ?? '1');
  url.searchParams.set('type', '2');
  url.searchParams.set('api_key', SERPAPI_KEY);

  try {
    const response = await fetch(url.toString());
    const data = await response.json();
    console.log('Full SerpApi response:', JSON.stringify(data, null, 2));
    res.json(data['best_flights'] ?? data['other_flights'] ?? []);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.listen(3000, () => console.log('Proxy running on http://localhost:3000'));
