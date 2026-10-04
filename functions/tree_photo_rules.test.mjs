import test from 'node:test';
import assert from 'node:assert/strict';

const host = process.env.FIRESTORE_EMULATOR_HOST;
const project = 'demo-tree-photo-validation';
const photos = ['https://res.cloudinary.com/test/image/upload/v1/tree.jpg'];

function token(uid) {
  const part = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${part({ alg: 'none', typ: 'JWT' })}.${part({
    sub: uid, user_id: uid, aud: project,
    iss: `https://securetoken.google.com/${project}`,
    iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 3600,
    firebase: { sign_in_provider: 'custom' },
  })}.`;
}

function field(value) {
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') return { doubleValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(field) } };
  return { mapValue: { fields: fields(value) } };
}

function fields(value) {
  return Object.fromEntries(Object.entries(value).map(([key, value]) => [key, field(value)]));
}

async function create(path, data, auth = 'owner') {
  return fetch(`http://${host}/v1/projects/${project}/databases/(default)/documents/${path}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${auth}` },
    body: JSON.stringify({ fields: fields(data) }),
  });
}

test('Firestore requires server-issued exact-photo receipt belonging to applicant', { skip: !host }, async () => {
  const auth = token('citizen');
  const base = {
    submittedByUid: 'citizen', status: 'pending',
    uploadedPaths: { treePicturesPaths: photos },
  };
  let index = 0;
  const permit = (data) => create(`tree_cutting_permits/permit${++index}`, { ...base, ...data }, auth);
  assert.equal((await permit({})).status, 403, 'missing receipt');
  assert.equal((await permit({ treePhotoValidationId: 'fake' })).status, 403, 'fabricated receipt');
  assert.equal((await create('treePhotoValidations/forged', {
    uid: 'citizen', imageUrls: photos, accepted: true,
    expiresAt: new Date(Date.now() + 3600000),
  }, auth)).status, 403, 'clients cannot issue receipts');

  for (const [id, data] of [
    ['valid', { uid: 'citizen', imageUrls: photos, accepted: true, expiresAt: new Date(Date.now() + 3600000) }],
    ['expired', { uid: 'citizen', imageUrls: photos, accepted: true, expiresAt: new Date(0) }],
    ['other', { uid: 'another-user', imageUrls: photos, accepted: true, expiresAt: new Date(Date.now() + 3600000) }],
  ]) assert.equal((await create(`treePhotoValidations/${id}`, data)).status, 200);

  assert.equal((await permit({ treePhotoValidationId: 'valid' })).status, 200, 'valid receipt');
  assert.equal((await permit({ treePhotoValidationId: 'expired' })).status, 403, 'expired receipt');
  assert.equal((await permit({ treePhotoValidationId: 'other' })).status, 403, 'wrong applicant');
  assert.equal((await permit({
    treePhotoValidationId: 'valid', uploadedPaths: { treePicturesPaths: [...photos, 'invalid'] },
  })).status, 403, 'adding unvalidated second photo');
  assert.equal((await permit({
    treePhotoValidationId: 'valid', uploadedPaths: { treePicturesPaths: [] },
  })).status, 403, 'empty photos');
});

test('unverified on-site receipts cannot be hidden or moved to another location', { skip: !host }, async () => {
  const auth = token('citizen');
  const trunk = 'https://res.cloudinary.com/test/image/upload/v1/trunk.jpg';
  const treePhotos = [...photos, trunk];
  const expiresAt = new Date(Date.now() + 3600000);
  assert.equal((await create('treePhotoValidations/onsite', {
    uid: 'citizen', imageUrls: treePhotos, accepted: true, expiresAt,
    speciesVerification: 'unverified_onsite', unverifiedPhotoUrls: [trunk],
    treeLatitude: 10.3157, treeLongitude: 123.8854,
  })).status, 200);
  const flagged = {
    submittedByUid: 'citizen', status: 'pending', treePhotoValidationId: 'onsite',
    uploadedPaths: { treePicturesPaths: treePhotos },
    speciesVerification: 'unverified_onsite', inspectionRequired: true,
    unverifiedTreePhotoUrls: [trunk], treeLatitude: 10.3157, treeLongitude: 123.8854,
  };
  let index = 0;
  const permit = (data) => create(`tree_cutting_permits/onsite${++index}`, { ...flagged, ...data }, auth);
  assert.equal((await permit({})).status, 200, 'flagged permit');
  assert.equal((await permit({ speciesVerification: 'verified' })).status, 403, 'hidden flag');
  const { speciesVerification, ...missingFlag } = flagged;
  assert.equal((await create('tree_cutting_permits/missing-flag', missingFlag, auth)).status, 403, 'omitted flag');
  assert.equal((await permit({ inspectionRequired: false })).status, 403, 'inspection skipped');
  assert.equal((await permit({ unverifiedTreePhotoUrls: [] })).status, 403, 'flagged photos hidden');
  assert.equal((await permit({ treeLatitude: 10.4 })).status, 403, 'moved location');
  assert.equal((await create('tree_cutting_permits/claims-unverified', {
    submittedByUid: 'citizen', status: 'pending', treePhotoValidationId: 'valid',
    uploadedPaths: { treePicturesPaths: photos }, speciesVerification: 'unverified_onsite',
  }, auth)).status, 403, 'flag must match receipt');
});