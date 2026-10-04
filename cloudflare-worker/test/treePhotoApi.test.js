import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';
import { commitUpdates } from '../src/organizationAdmin.js';

test('photo validation has web CORS preflight', async () => {
  const response = await worker.fetch(new Request('https://test/validateTreePhotos', {
    method: 'OPTIONS', headers: { Origin: 'http://localhost:51576' },
  }), {});
  assert.equal(response.status, 204);
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), 'http://localhost:51576');
});

test('photo validation cannot issue receipts without Firebase authentication', async () => {
  const response = await worker.fetch(new Request('https://test/validateTreePhotos', {
    method: 'POST', body: '{"imageUrls":["photo"]}',
  }), {});
  assert.equal(response.status, 401);
  const result = await response.json();
  assert.equal(result.code, 'unauthenticated');
  assert.equal(result.validationId, undefined);
  assert.equal(result.details, undefined);
});

test('upstream no-match returns 422 without raw API payload', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) => String(url).includes('my-api.plantnet.org')
    ? new Response('{"message":"Species not found","private":"upstream-details"}', { status: 404 })
    : new Response(new Uint8Array([1, 2, 3]));
  try {
    const response = await worker.fetch(new Request('https://test/identifySpecies', {
      method: 'POST', body: '{"imageUrls":["https://image.example/photo.jpg"]}',
    }), { PLANTNET_API_KEY: 'test-key' });
    assert.equal(response.status, 422);
    const result = await response.json();
    assert.equal(result.code, 'no_match');
    assert.equal(result.details, undefined);
    assert.equal(JSON.stringify(result).includes('upstream-details'), false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('missing recognition configuration returns safe backend-not-ready error', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => new Response(new Uint8Array([1, 2, 3]));
  try {
    const response = await worker.fetch(new Request('https://test/identifySpecies', {
      method: 'POST', body: '{"imageUrls":["https://image.example/photo.jpg"]}',
    }), {});
    assert.equal(response.status, 503);
    const result = await response.json();
    assert.equal(result.code, 'backend_not_ready');
    assert.equal(JSON.stringify(result).includes('PLANTNET_API_KEY'), false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('receipt expiration is persisted as Firestore timestamp, not an empty map', async () => {
  const originalFetch = globalThis.fetch;
  const expiresAt = new Date('2030-01-01T00:00:00Z');
  let writes;
  globalThis.fetch = async (_, options) => {
    writes = JSON.parse(options.body).writes;
    return Response.json({});
  };
  try {
    await commitUpdates('demo', 'test-token', [{
      path: 'treePhotoValidations/id',
      fields: { uid: 'citizen', imageUrls: ['photo'], accepted: true, expiresAt },
    }]);
    assert.deepEqual(writes[0].update.fields.expiresAt, {
      timestampValue: expiresAt.toISOString(),
    });
    assert.deepEqual(writes[0].currentDocument, { exists: false });
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('photo download uses Worker-supported redirect mode and recognition still succeeds', async () => {
  const originalFetch = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (url, options) => {
    calls.push(String(url));
    if (String(url).includes('my-api.plantnet.org')) {
      return Response.json({
        results: [{ score: 0.9, species: { scientificNameWithoutAuthor: 'Mangifera indica' } }],
      });
    }
    assert.equal(options.redirect, 'manual');
    assert.ok(options.signal instanceof AbortSignal);
    return new Response(new Uint8Array([1, 2, 3]));
  };
  try {
    const response = await worker.fetch(new Request('https://test/identifySpecies', {
      method: 'POST', body: '{"imageUrls":["https://image.example/photo.jpg"]}',
    }), { PLANTNET_API_KEY: 'test-key' });
    assert.equal(response.status, 200);
    assert.equal((await response.json()).bestMatch.scientificName, 'Mangifera indica');
    assert.equal(calls.length, 2);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('redirected photos fail closed without following the redirect or calling recognition', async () => {
  const originalFetch = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = async (_, options) => {
    calls++;
    assert.equal(options.redirect, 'manual');
    return new Response(null, {
      status: 302, headers: { Location: 'https://different.example/photo.jpg' },
    });
  };
  try {
    const response = await worker.fetch(new Request('https://test/identifySpecies', {
      method: 'POST', body: '{"imageUrls":["https://image.example/photo.jpg"]}',
    }), { PLANTNET_API_KEY: 'test-key' });
    assert.equal(response.status, 503);
    assert.equal((await response.json()).code, 'photo_unavailable');
    assert.equal(calls, 1);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('unverified on-site receipt persists flag and tree coordinates as Firestore values', async () => {
  const { receiptFields } = await import('../../functions/tree_photo_validation.mjs');
  const originalFetch = globalThis.fetch;
  let writes;
  globalThis.fetch = async (_, options) => {
    writes = JSON.parse(options.body).writes;
    return Response.json({});
  };
  try {
    await commitUpdates('demo', 'test-token', [{
      path: 'treePhotoValidations/id',
      fields: receiptFields({
        uid: 'citizen', imageUrls: ['leaf', 'trunk'], expiresAt: new Date('2030-01-01T00:00:00Z'),
        result: { unverifiedIndexes: [1], speciesVerification: 'unverified_onsite' },
        treeLocation: { latitude: 10.3157, longitude: 124 },
      }),
    }]);
    const fields = writes[0].update.fields;
    assert.deepEqual(fields.speciesVerification, { stringValue: 'unverified_onsite' });
    assert.deepEqual(fields.unverifiedPhotoUrls, {
      arrayValue: { values: [{ stringValue: 'trunk' }] },
    });
    assert.deepEqual(fields.treeLatitude, { doubleValue: 10.3157 });
    assert.deepEqual(fields.treeLongitude, { integerValue: '124' });
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('a confident bark classifier call boosts a low-confidence, agreeing Pl@ntNet bark photo', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) => {
    const target = String(url);
    if (target.includes('my-api.plantnet.org')) {
      return Response.json({
        results: [{ score: 0.3, species: { scientificNameWithoutAuthor: 'Pterocarpus indicus' } }],
      });
    }
    if (target === 'https://bark.example/predict') {
      return Response.json({ predictions: [{ label: 'Narra', confidence: 0.95 }] });
    }
    return new Response(new Uint8Array([1, 2, 3]));
  };
  try {
    const response = await worker.fetch(new Request('https://test/identifySpecies', {
      method: 'POST', body: '{"imageUrls":["https://image.example/bark.jpg"]}',
    }), { PLANTNET_API_KEY: 'test-key', BARK_CLASSIFIER_URL: 'https://bark.example' });
    assert.equal(response.status, 200);
    const result = await response.json();
    assert.equal(result.bestMatch.matchedDropdownLabel, 'Narra');
    assert.equal(result.bestMatch.confidence, 0.9); // capped agreement boost (see DEFAULT_AGREEMENT_CONFIDENCE_CAP)
    assert.deepEqual(result.bestMatch.barkFusion, { agreed: true, barkConfidence: 0.95 });
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('a confident bark classifier call rescues a photo Pl@ntNet could not recognize at all', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) => {
    const target = String(url);
    if (target.includes('my-api.plantnet.org')) {
      return new Response('{"message":"Species not found"}', { status: 404 });
    }
    if (target === 'https://bark.example/predict') {
      return Response.json({ predictions: [{ label: 'Coconut', confidence: 0.88 }] });
    }
    return new Response(new Uint8Array([1, 2, 3]));
  };
  try {
    const response = await worker.fetch(new Request('https://test/identifySpecies', {
      method: 'POST', body: '{"imageUrls":["https://image.example/trunk.jpg"]}',
    }), { PLANTNET_API_KEY: 'test-key', BARK_CLASSIFIER_URL: 'https://bark.example' });
    assert.equal(response.status, 200);
    const result = await response.json();
    assert.equal(result.bestMatch.matchedDropdownLabel, 'Coconut');
    assert.equal(result.bestMatch.scientificName, 'Cocos nucifera');
    assert.equal(result.bestMatch.confidence, 0.7);
    assert.deepEqual(result.bestMatch.barkFusion, {
      agreed: false, barkConfidence: 0.88, soloSource: true,
    });
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('bark classifier outages never affect identifySpecies — Pl@ntNet-only result is returned', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) => {
    const target = String(url);
    if (target.includes('my-api.plantnet.org')) {
      return Response.json({
        results: [{ score: 0.9, species: { scientificNameWithoutAuthor: 'Cocos nucifera' } }],
      });
    }
    if (target === 'https://bark.example/predict') {
      throw new Error('connection refused');
    }
    return new Response(new Uint8Array([1, 2, 3]));
  };
  try {
    const response = await worker.fetch(new Request('https://test/identifySpecies', {
      method: 'POST', body: '{"imageUrls":["https://image.example/photo.jpg"]}',
    }), { PLANTNET_API_KEY: 'test-key', BARK_CLASSIFIER_URL: 'https://bark.example' });
    assert.equal(response.status, 200);
    const result = await response.json();
    assert.equal(result.bestMatch.scientificName, 'Cocos nucifera');
    assert.equal(result.bestMatch.confidence, 0.9);
    assert.equal(result.bestMatch.barkFusion, undefined);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

