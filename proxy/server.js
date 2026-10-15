const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');
const { createGeminiClient } = require('./geminiClient');
const { createRecommendationDataLoader } = require('./recommendationData');
const { rateLimit, MemoryStore } = require('express-rate-limit');
const {
  createAuthenticateMiddleware,
  createRecommendationsHandler,
  rateLimitedHandler,
  bodyErrorHandler,
} = require('./recommendationRoute');

const app = express();
// Behind a load balancer (e.g. Cloud Run) req.ip is the balancer's address
// unless Express trusts its X-Forwarded-For; set TRUST_PROXY_HOPS=1 there so
// the per-IP rate limit sees real clients. Left off locally so the header
// can't be spoofed.
const TRUST_PROXY_HOPS = Number.parseInt(process.env.TRUST_PROXY_HOPS || '0', 10);
if (TRUST_PROXY_HOPS > 0) app.set('trust proxy', TRUST_PROXY_HOPS);
app.use(cors());
app.use('/airports', require('./airports').createAirportRouter());
 
const SERPAPI_KEY = process.env.SERPAPI_KEY;
if (!SERPAPI_KEY && require.main === module) {
  console.error(
    'Missing SERPAPI_KEY. Set it in the environment (see proxy/.env.example) before starting the proxy.'
  );
  process.exit(1);
}

// Used by /flights so the SerpApi request can be mocked in automated tests.
let flightFetch = fetch;

function setFlightFetch(mockFetch) {
  flightFetch = mockFetch;
}

function resetFlightFetch() {
  flightFetch = fetch;
}
 
// GET /flights?origin=&destination=&departureDate=&adults=&returnDate=
// If returnDate is provided, this is a round-trip search (type=1) and each
// returned offer carries a `departure_token` you send to /flights/return to
// get the matching return-leg options. Without returnDate it's one-way
// (type=2) same as before.
app.get('/flights', async (req, res) => {
  const { origin, destination, departureDate, adults, returnDate } = req.query;

  if (!origin || !destination || !departureDate) {
    return res.status(400).json({
      error: 'origin, destination, and departureDate are required',
    });
  }

  if (adults !== undefined && !/^\d+$/.test(adults)) {
    return res.status(400).json({
      error: 'adults must be numeric',
    });
  }

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
    const response = await flightFetch(url.toString());
    const data = await response.json();

    if (data['best_flights']?.length) {
      res.json(data['best_flights']);
    } else {
      res.json(data['other_flights'] ?? []);
    }
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

// GET /hotels?location=&checkInDate=&checkOutDate=&adults=
app.get('/hotels', async (req, res) => {
  const { location, checkInDate, checkOutDate, adults } = req.query;

  if (!location || !checkInDate || !checkOutDate) {
    return res.status(400).json({
      error: 'location, checkInDate, and checkOutDate are required',
    });
  }

  const url = new URL('https://serpapi.com/search');
  url.searchParams.set('engine', 'google_hotels');
  url.searchParams.set('q', location);
  url.searchParams.set('check_in_date', checkInDate);
  url.searchParams.set('check_out_date', checkOutDate);
  url.searchParams.set('adults', adults ?? '1');
  url.searchParams.set('currency', 'USD');
  url.searchParams.set('api_key', SERPAPI_KEY);

  try {
    const response = await fetch(url.toString());
    const data = await response.json();

    res.json(data['properties'] ?? []);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Real dependencies are built per call, so firebase-admin and the Gemini key
// are only touched by /recommendations. Tests swap them via setRecommendationDeps.
const defaultRecommendationDeps = {
  verifyIdToken: (header) => require('./firebaseAdmin').verifyIdTokenFromHeader(header),
  loadRawData: async (args) =>
    createRecommendationDataLoader(await require('./firebaseAdmin').getFirestore()).loadRawData(args),
  geminiClient: { generateRecommendation: (args) => createGeminiClient().generateRecommendation(args) },
};
let recommendationDeps = defaultRecommendationDeps;

function setRecommendationDeps(deps) {
  recommendationDeps = { ...defaultRecommendationDeps, ...deps };
}

function resetRecommendationDeps() {
  recommendationDeps = defaultRecommendationDeps;
}

// Each allowed /recommendations call costs a Gemini request, so cap it per
// client IP (checked first, before any token or body work) and per verified
// user. In-memory counters are per instance: with N instances the effective
// cap is up to N times these numbers.
const RECOMMENDATION_RATE_WINDOW_MS = 60 * 1000;
const RECOMMENDATION_IP_LIMIT = 30;
const RECOMMENDATION_USER_LIMIT = 10;

const recommendationIpStore = new MemoryStore();
const recommendationUserStore = new MemoryStore();
const rateLimitOptions = {
  windowMs: RECOMMENDATION_RATE_WINDOW_MS,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  handler: rateLimitedHandler,
};
const recommendationIpLimiter = rateLimit({
  ...rateLimitOptions,
  limit: RECOMMENDATION_IP_LIMIT,
  store: recommendationIpStore,
});
const recommendationUserLimiter = rateLimit({
  ...rateLimitOptions,
  limit: RECOMMENDATION_USER_LIMIT,
  store: recommendationUserStore,
  keyGenerator: (req, res) => res.locals.uid,
});

function resetRecommendationRateLimits() {
  recommendationIpStore.resetAll();
  recommendationUserStore.resetAll();
}

// POST /recommendations — Bearer Firebase ID token required; see recommendationRoute.js.
app.post(
  '/recommendations',
  recommendationIpLimiter,
  express.json({ limit: '32kb' }),
  bodyErrorHandler,
  (req, res, next) => createAuthenticateMiddleware(recommendationDeps)(req, res, next),
  recommendationUserLimiter,
  (req, res) => createRecommendationsHandler(recommendationDeps)(req, res)
);

if (require.main === module) {
  app.listen(3000, () => console.log('Proxy running on http://localhost:3000'));
}

module.exports = {
  app,
  setFlightFetch,
  resetFlightFetch,
  setRecommendationDeps,
  resetRecommendationDeps,
  resetRecommendationRateLimits,
  RECOMMENDATION_IP_LIMIT,
  RECOMMENDATION_USER_LIMIT,
};