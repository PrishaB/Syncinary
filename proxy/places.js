const express = require('express');
const fetch = require('node-fetch');

// Keep API keys and raw upstream metadata on the server.
function createPlaceRouter({ apiKey = process.env.SERPAPI_KEY, fetchImpl = fetch } = {}) {
  const router = express.Router();
  router.get('/', async (req, res) => {
    res.set('Cache-Control', 'no-store');
    const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    if (query.length < 2 || query.length > 200) {
      return res.status(400).json({ error: 'Enter a place name or address (2–200 characters).' });
    }
    if (!apiKey) {
      return res.status(503).json({ error: 'Place search is not configured.' });
    }
    const url = new URL('https://serpapi.com/search.json');
    url.searchParams.set('engine', 'google_maps');
    url.searchParams.set('type', 'search');
    url.searchParams.set('q', query);
    url.searchParams.set('hl', 'en');
    url.searchParams.set('api_key', apiKey);
    try {
      const response = await fetchImpl(url.toString(), { timeout: 10000 });
      if (!response.ok) throw new Error('Place search failed');
      const data = await response.json();
      if (data.error) throw new Error('Place search failed');
      const results = Array.isArray(data.local_results) ? data.local_results :
        (data.place_results ? [data.place_results] : []);
      const places = [];
      const seen = new Set();
      for (const result of results) {
        const { latitude, longitude } = result?.gps_coordinates || {};
        if (typeof result?.title !== 'string' || !result.title.trim() ||
            !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
            Math.abs(latitude) > 90 || Math.abs(longitude) > 180) continue;
        const id = `${result.title}:${latitude}:${longitude}`;
        if (seen.has(id)) continue;
        seen.add(id);
        places.push({ name: result.title, address: typeof result.address === 'string' ? result.address : '', latitude, longitude });
        if (places.length === 10) break;
      }
      return res.json({ places });
    } catch {
      return res.status(502).json({ error: 'Place search is unavailable. Please try again.' });
    }
  });
  return router;
}

module.exports = { createPlaceRouter };
