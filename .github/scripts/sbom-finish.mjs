// Finishes the Syft CycloneDX SBOM, then checks it.
//
// Syft has no license lookup for Dart packages, so this fills in:
//   - pub.dev packages: the license pub.dev reports for that exact version
//   - Flutter SDK packages (flutter, flutter_test, ...): BSD-3-Clause, with the
//     version set to the Flutter SDK used by the build (FLUTTER_VERSION)
// Then it fails if any third-party component lacks a version or a license.
//
// Usage: FLUTTER_VERSION=3.47.2 node .github/scripts/sbom-finish.mjs SBOM.json

import { readFile, writeFile } from 'node:fs/promises';

const path = process.argv[2];
if (!path) {
  console.error('usage: node sbom-finish.mjs <SBOM.json>');
  process.exit(2);
}
const flutterVersion = process.env.FLUTTER_VERSION;

// Our own packages; they are the project, not third-party dependencies.
const FIRST_PARTY = new Set(['syncinary', 'syncinary-proxy']);

// pub.dev license tags -> SPDX IDs. Unlisted tags are kept as license names.
const SPDX = {
  'apache-2.0': 'Apache-2.0',
  'bsd-2-clause': 'BSD-2-Clause',
  'bsd-3-clause': 'BSD-3-Clause',
  'bsd-3-clause-hp': 'BSD-3-Clause-HP',
  'isc': 'ISC',
  'mit': 'MIT',
  'mpl-2.0': 'MPL-2.0',
  'unlicense': 'Unlicense',
  'zlib': 'Zlib',
};
// Tags that describe a license category, not a license.
const NOT_LICENSES = new Set(['fsf-libre', 'osi-approved', 'unknown']);

const bom = JSON.parse(await readFile(path, 'utf8'));
const components = bom.components ?? [];

const toLicense = (tag) =>
  SPDX[tag] ? { license: { id: SPDX[tag] } } : { license: { name: tag } };

async function pubLicenses(name, version) {
  const base = `https://pub.dev/api/packages/${encodeURIComponent(name)}`;
  // Exact version first; latest as a fallback.
  for (const url of [`${base}/versions/${encodeURIComponent(version)}/score`, `${base}/score`]) {
    const res = await fetch(url);
    if (!res.ok) continue;
    const { tags = [] } = await res.json();
    const licenses = tags
      .filter((t) => t.startsWith('license:'))
      .map((t) => t.slice('license:'.length))
      .filter((t) => !NOT_LICENSES.has(t));
    if (licenses.length) return licenses.map(toLicense);
  }
  return null;
}

const pub = components.filter(
  (c) => c.type === 'library' && c.purl?.startsWith('pkg:pub/') && !FIRST_PARTY.has(c.name),
);

const jobs = pub.map((c) => async () => {
  if (!c.purl.includes('hosted_url=')) {
    // SDK package: ships with Flutter, which is BSD-3-Clause.
    c.licenses = [{ license: { id: 'BSD-3-Clause' } }];
    if (flutterVersion) {
      c.purl = c.purl.replace(`@${c.version}`, `@${flutterVersion}`);
      c.version = flutterVersion;
    }
    return;
  }
  if (!c.licenses?.length) {
    const licenses = await pubLicenses(c.name, c.version);
    if (licenses) c.licenses = licenses;
  }
});

// Runs the pub.dev lookups 8 at a time.
const queue = [...jobs];
await Promise.all(
  Array.from({ length: 8 }, async () => {
    while (queue.length) await queue.shift()();
  }),
);

await writeFile(path, JSON.stringify(bom, null, 2) + '\n');

const thirdParty = components.filter((c) => c.type === 'library' && !FIRST_PARTY.has(c.name));
const missing = thirdParty.filter((c) => !c.version || !c.licenses?.length);
console.log(`SBOM: ${thirdParty.length} third-party components`);
if (missing.length) {
  console.error('Missing version or license:');
  for (const c of missing) console.error(`  ${c.purl ?? c.name}`);
  process.exit(1);
}
console.log('Every third-party component has a version and a license.');
