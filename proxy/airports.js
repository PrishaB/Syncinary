const express = require('express');
const fetch = require('node-fetch');
const airports = require('./data/airports.json');

function distanceKm(a, b) {
  const rad = Math.PI / 180;
  const dLat = (a.latitude - b.latitude) * rad;
  const dLon = (a.longitude - b.longitude) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.latitude * rad) *
    Math.cos(b.latitude * rad) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(Math.min(1, h)));
}

function nameWords(name) {
  return name.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().replace(/[^a-z0-9 ]/g, ' ').split(/\s+/)
    .filter(word => word && !['airport', 'international', 'intl', 'regional', 'airfield', 'the'].includes(word));
}

// Fail closed: coordinates alone could identify a neighbouring airfield.
// Require a unique nearby airport AND agreement on its name (or explicit code).
function resolveAirport(place, catalog = airports) {
  const location = place.location;
  if (!place.types?.includes('airport') || !location ||
      !Number.isFinite(location.latitude) || !Number.isFinite(location.longitude)) return null;
  const nearby = catalog.filter(airport => distanceKm(location, airport) <= 5);
  if (nearby.length !== 1) return null;
  const airport = nearby[0];
  const name = place.displayName?.text || '';
  const words = nameWords(airport.name);
  const googleWords = new Set(nameWords(name));
  const shared = words.filter(word => googleWords.has(word)).length;
  const explicitCode = new RegExp(`\\b${airport.code}\\b`).test(name);
  if (!explicitCode && (words.length === 0 || googleWords.size === 0 ||
      shared < Math.min(2, words.length, googleWords.size))) return null;
  return { code: airport.code, name, address: place.formattedAddress || '' };
}

function createAirportRouter({ apiKey = process.env.GOOGLE_MAPS_API_KEY, fetchImpl = fetch, catalog = airports } = {}) {
  const router = express.Router();
  router.get('/', async (req, res) => {
    const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    res.set('Cache-Control', 'no-store');
    if (query.length < 2 || query.length > 120) {
      return res.status(400).json({ error: 'Enter between 2 and 120 characters.' });
    }
    // Known IATA codes also work without Google configuration or connectivity.
    const exact = catalog.find(airport => airport.code === query.toUpperCase());
    if (exact) return res.json({ airports: [{ code: exact.code, name: exact.name, address: exact.city }], source: 'OurAirports' });
    if (!apiKey) return res.status(503).json({ error: 'Airport suggestions are not configured. Enter an airport code instead.' });
    try {
      const response = await fetchImpl('https://places.googleapis.com/v1/places:searchText', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'places.displayName,places.formattedAddress,places.location,places.types,places.attributions',
        },
        body: JSON.stringify({ textQuery: `airports ${query}`, includedType: 'airport', strictTypeFiltering: true, pageSize: 10, languageCode: 'en' }),
        timeout: 8000,
      });
      if (!response.ok) throw new Error('Google Places request failed');
      const data = await response.json();
      const seen = new Set();
      const resolved = [];
      for (const place of data.places || []) {
        const airport = resolveAirport(place, catalog);
        if (!airport || seen.has(airport.code)) continue;
        seen.add(airport.code);
        resolved.push({ ...airport, attributions: place.attributions || [] });
      }
      return res.json({ airports: resolved, source: 'Google Maps' });
    } catch {
      return res.status(502).json({ error: 'Airport suggestions are unavailable. Try again or enter an airport code.' });
    }
  });
  return router;
}

module.exports = { createAirportRouter, resolveAirport };
