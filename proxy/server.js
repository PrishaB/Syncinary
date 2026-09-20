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
 
// GET /flights?origin=&destination=&departureDate=&adults=&returnDate=
// If returnDate is provided, this is a round-trip search (type=1) and each
// returned offer carries a `departure_token` you send to /flights/return to
// get the matching return-leg options. Without returnDate it's one-way
// (type=2) same as before.
app.get('/flights', async (req, res) => {
  const { origin, destination, departureDate, adults, returnDate } = req.query;
  const url = new URL('https://serpapi.com/search');
  url.searchParams.set('engine', 'google_flights');
  url.searchParams.set('departure_id', origin);
  url.searchParams.set('arrival_id', destination);
  url.searchParams.set('outbound_date', departureDate);
  url.searchParams.set('adults', adults ?? '1');
 
  if (returnDate) {
    url.searchParams.set('type', '1'); // round trip
    url.searchParams.set('return_date', returnDate);
  } else {
    url.searchParams.set('type', '2'); // one way
  }
 
  url.searchParams.set('api_key', SERPAPI_KEY);
 
  try {
    const response = await fetch(url.toString());
    const data = await response.json();
    res.json(data['best_flights'] ?? data['other_flights'] ?? []);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});
 
// GET /flights/return?origin=&destination=&departureDate=&returnDate=&adults=&departureToken=
// Round trips are a two-step search in SerpApi: once the user picks an
// outbound offer from /flights, its `departure_token` is sent here (along
// with the same original search params) to get that offer's matching
// return-leg options.
app.get('/flights/return', async (req, res) => {
  const { origin, destination, departureDate, returnDate, adults, departureToken } =
    req.query;
 
  if (!departureToken) {
    return res.status(400).json({ error: 'departureToken is required' });
  }
 
  const url = new URL('https://serpapi.com/search');
  url.searchParams.set('engine', 'google_flights');
  url.searchParams.set('departure_id', origin);
  url.searchParams.set('arrival_id', destination);
  url.searchParams.set('outbound_date', departureDate);
  url.searchParams.set('return_date', returnDate);
  url.searchParams.set('adults', adults ?? '1');
  url.searchParams.set('type', '1');
  url.searchParams.set('departure_token', departureToken);
  url.searchParams.set('api_key', SERPAPI_KEY);
 
  try {
    const response = await fetch(url.toString());
    const data = await response.json();
    res.json(data['best_flights'] ?? data['other_flights'] ?? []);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});
 
// GET /flights/booking?origin=&destination=&departureDate=&adults=&returnDate=&bookingToken=
// Booking links aren't included on the initial search — SerpApi requires a
// second lookup with the offer's `booking_token` plus the same original
// search params. Returns SerpApi's raw `booking_options` array. Note: some
// booking options link out with a plain `url`; others require POSTing
// `post_data` to `booking_request.url` (a real airline/OTA checkout form),
// which the client can't just open as a link — those show as a "search on
// Google Flights" fallback instead.
app.get('/flights/booking', async (req, res) => {
  const { origin, destination, departureDate, adults, returnDate, bookingToken } =
    req.query;
 
  if (!bookingToken) {
    return res.status(400).json({ error: 'bookingToken is required' });
  }
 
  const url = new URL('https://serpapi.com/search');
  url.searchParams.set('engine', 'google_flights');
  url.searchParams.set('departure_id', origin);
  url.searchParams.set('arrival_id', destination);
  url.searchParams.set('outbound_date', departureDate);
  url.searchParams.set('adults', adults ?? '1');
  if (returnDate) {
    url.searchParams.set('type', '1');
    url.searchParams.set('return_date', returnDate);
  } else {
    url.searchParams.set('type', '2');
  }
  url.searchParams.set('booking_token', bookingToken);
  url.searchParams.set('api_key', SERPAPI_KEY);
 
  try {
    const response = await fetch(url.toString());
    const data = await response.json();
    res.json(data['booking_options'] ?? []);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});
 
app.listen(3000, () => console.log('Proxy running on http://localhost:3000'));
 