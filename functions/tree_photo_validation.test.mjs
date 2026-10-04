import test from 'node:test';
import assert from 'node:assert/strict';
import {
  plantNetFailure, validateEachPhoto, validatePhotoUrls, requireRecognizedPhoto,
  parseOnSiteEvidence, receiptFields, distanceMeters, ON_SITE_MAX_AGE_MS,
  SPECIES_VERIFIED, SPECIES_UNVERIFIED_ON_SITE,
} from './tree_photo_validation.mjs';

test('PlantNet no-match, quota and outages have safe distinct errors', () => {
  assert.equal(plantNetFailure(404).code, 'no_match');
  assert.equal(plantNetFailure(404).status, 422);
  assert.equal(plantNetFailure(429).code, 'rate_limited');
  assert.equal(plantNetFailure(500).code, 'service_unavailable');
  assert.equal(plantNetFailure(401).status, 503);
});

test('exact confidence threshold rejects invalid and uncertain results', () => {
  for (const confidence of [0.499, NaN, Infinity, -1, 1.01]) {
    assert.throws(() => requireRecognizedPhoto([{ scientificName: 'Tree', confidence }]));
  }
  assert.throws(() => requireRecognizedPhoto([]), (e) => e.code === 'no_match');
  requireRecognizedPhoto([{ scientificName: 'Tree', confidence: 0.5 }]);
});

test('valid first photo cannot mask invalid second photo', async () => {
  const seen = [];
  await assert.rejects(validateEachPhoto(['leaf', 'non-plant'], async (url) => {
    seen.push(url);
    return url === 'leaf' ? [{ scientificName: 'Tree', confidence: 0.9 }] : [];
  }), (e) => e.code === 'no_match' && e.photoIndex === 1);
  assert.deepEqual(seen, ['leaf', 'non-plant']);
});

test('low-confidence diagnostics preserve real scores and sanitize invalid scores', async () => {
  for (const confidence of [0.01, 0.499, NaN, Infinity, -1, 1.01]) {
    await assert.rejects(validateEachPhoto(['photo'], async () =>
      [{ scientificName: 'Tree', confidence }]), (error) => {
      assert.equal(error.code, 'low_confidence');
      assert.equal(error.photoIndex, 0);
      assert.equal(error.confidence,
        Number.isFinite(confidence) && confidence >= 0 && confidence <= 1 ? confidence : null);
      assert.equal(error.message.includes('not clear enough'), false);
      return true;
    });
  }
});

test('every photo must succeed; outages fail closed', async () => {
  await assert.rejects(validateEachPhoto(['photo'], async () => {
    throw plantNetFailure(503);
  }), (e) => e.code === 'service_unavailable' && e.photoIndex === 0);
  await validateEachPhoto(['leaf', 'bark'], async () =>
    [{ scientificName: 'Tree', confidence: 0.75 }]);
});

test('validation only fetches immutable images in configured Cloudinary cloud', () => {
  validatePhotoUrls(['https://res.cloudinary.com/mycloud/image/upload/v123/tree.jpg'], 'mycloud');
  for (const url of [
    'http://localhost/private', 'https://example.com/tree.jpg',
    'https://res.cloudinary.com/another/image/upload/v123/tree.jpg',
    'https://res.cloudinary.com/mycloud/image/upload/tree.jpg',
    'https://res.cloudinary.com/mycloud/image/upload/v1/tree.jpg?x=1',
    'https://res.cloudinary.com/mycloud/raw/upload/v1/doc.pdf',
  ]) assert.throws(() => validatePhotoUrls([url], 'mycloud'));
  assert.throws(() => validatePhotoUrls([], 'mycloud'));
});

test('on-site fallback accepts only uncertain recognition with accurate nearby capture', async () => {
  const now = Date.parse('2026-01-01T00:00:00Z');
  const tree = { latitude: 10.3157, longitude: 123.8854 };
  const body = {
    imageUrls: ['leaf', 'trunk'],
    treeLocation: tree,
    onSiteCaptures: [{
      url: 'trunk', latitude: 10.3159, longitude: 123.8855,
      accuracyMeters: 12, capturedAt: new Date(now - 60000).toISOString(),
    }],
  };
  const { captures, treeLocation } = parseOnSiteEvidence(body, body.imageUrls);
  const identify = async (url) => url === 'leaf'
    ? [{ scientificName: 'Tree', confidence: 0.8 }]
    : [{ scientificName: 'Tree', confidence: 0.1 }];
  const result = await validateEachPhoto(body.imageUrls, identify,
    { onSite: captures, treeLocation, now });
  assert.deepEqual(result, { unverifiedIndexes: [1], speciesVerification: SPECIES_UNVERIFIED_ON_SITE });
  const receipt = receiptFields({ uid: 'u', imageUrls: body.imageUrls, expiresAt: 'x', result, treeLocation });
  assert.deepEqual(receipt.unverifiedPhotoUrls, ['trunk']);
  assert.equal(receipt.treeLatitude, tree.latitude);

  const verified = await validateEachPhoto(['leaf'], identify);
  assert.equal(verified.speciesVerification, SPECIES_VERIFIED);
  assert.equal(receiptFields({ uid: 'u', imageUrls: ['leaf'], expiresAt: 'x', result: verified })
    .unverifiedPhotoUrls, undefined);

  // Without on-site capture, the same uncertain photo is still rejected.
  await assert.rejects(validateEachPhoto(body.imageUrls, identify, { now }),
    (e) => e.code === 'low_confidence' && e.photoIndex === 1);
});

test('on-site fallback rejects far, inaccurate, stale, future, and outage cases', async () => {
  const now = Date.parse('2026-01-01T00:00:00Z');
  const tree = { latitude: 10, longitude: 123 };
  const base = { url: 'p', latitude: 10, longitude: 123, accuracyMeters: 10, capturedAt: now };
  const cases = [
    [{ ...base, latitude: 10.002 }, 'onsite_too_far'],
    [{ ...base, accuracyMeters: 80 }, 'onsite_gps_unreliable'],
    [{ ...base, capturedAt: now - ON_SITE_MAX_AGE_MS - 1 }, 'onsite_gps_unreliable'],
    [{ ...base, capturedAt: now + 60 * 60 * 1000 }, 'onsite_gps_unreliable'],
  ];
  for (const [capture, code] of cases) {
    await assert.rejects(validateEachPhoto(['p'], async () => [],
      { onSite: new Map([['p', capture]]), treeLocation: tree, now }),
    (e) => e.code === code && e.status === 422 && e.photoIndex === 0);
  }
  await assert.rejects(validateEachPhoto(['p'], async () => { throw plantNetFailure(503); },
    { onSite: new Map([['p', base]]), treeLocation: tree, now }),
  (e) => e.code === 'service_unavailable');
  await assert.rejects(validateEachPhoto(['p'], async () => { throw plantNetFailure(429); },
    { onSite: new Map([['p', base]]), treeLocation: tree, now }),
  (e) => e.code === 'rate_limited');
  assert.ok(Math.abs(distanceMeters({ latitude: 0, longitude: 0 }, { latitude: 0.001, longitude: 0 }) - 111.2) < 1);
});

test('on-site evidence input is strictly shaped', () => {
  const urls = ['a'];
  const location = { latitude: 1, longitude: 2 };
  const capture = { url: 'a', latitude: 1, longitude: 2, accuracyMeters: 5, capturedAt: '2026-01-01T00:00:00Z' };
  assert.equal(parseOnSiteEvidence({}, urls).captures.size, 0);
  for (const body of [
    { onSiteCaptures: [capture] },
    { onSiteCaptures: [capture], treeLocation: { latitude: 91, longitude: 0 } },
    { onSiteCaptures: [{ ...capture, url: 'other' }], treeLocation: location },
    { onSiteCaptures: [capture, capture], treeLocation: location },
    { onSiteCaptures: [{ ...capture, latitude: '1' }], treeLocation: location },
    { onSiteCaptures: [{ ...capture, accuracyMeters: -1 }], treeLocation: location },
    { onSiteCaptures: [{ ...capture, capturedAt: 'nope' }], treeLocation: location },
    { onSiteCaptures: {}, treeLocation: location },
  ]) assert.throws(() => parseOnSiteEvidence(body, urls), (e) => e.code === 'invalid_photos');
});
