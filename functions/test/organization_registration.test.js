const test = require('node:test');
const assert = require('node:assert/strict');
const {
  OrganizationRegistrationError,
  createOrganizationHandlers,
  legacyPermitFingerprint,
  normalizeValue,
  permitFingerprint,
  requiredText,
  validatePermitDocument,
} = require('../organization_registration');

function createOrganizationDb(records) {
  const documents = new Map(Object.entries(records));

  function documentRef(path) {
    return {
      id: path.split('/').at(-1),
      path,
      get: async () => {
        const value = documents.get(path);
        return { exists: value != null, data: () => value };
      },
      collection(name) {
        return collectionRef(`${path}/${name}`);
      },
    };
  }

  function collectionRef(path) {
    return { doc: (id) => documentRef(`${path}/${id}`) };
  }

  const db = {
    collection: (name) => collectionRef(name),
    runTransaction: (callback) => callback({
      get: async (ref) => {
        const value = documents.get(ref.path);
        return { exists: value != null, data: () => value };
      },
      update: (ref, updates) => {
        const value = documents.get(ref.path);
        if (value == null) throw new Error(`Missing test document: ${ref.path}`);
        documents.set(ref.path, { ...value, ...updates });
      },
    }),
  };

  return { db, documents };
}

function pendingOrganizationRecords(uid = 'rep-1') {
  return {
    'organizations/org-1': {
      legalName: 'Green Valley Cooperative',
      primaryRepresentativeUid: 'rep-1',
      verificationStatus: 'pending',
    },
    [`organizations/org-1/members/${uid}`]: {
      uid,
      role: 'primary_representative',
      status: 'pending',
    },
    'organizations/org-1/private/verification': {
      permitDocumentUrl: 'https://res.cloudinary.com/dfo5l4d4t/raw/upload/old.pdf',
      permitIssuer: 'City Hall',
    },
    [ `users/${uid}` ]: { organizationId: 'org-1' },
  };
}

test('normalizes organization names and permit identifiers', () => {
  assert.equal(normalizeValue('  Société Verde, Inc.  '), 'societe verde inc');
  assert.equal(normalizeValue('BP- 001 / 2026'), 'bp 001 2026');
});

test('permit fingerprint is stable across formatting differences', () => {
  const first = permitFingerprint({
    issuer: 'City Hall',
    jurisdiction: 'Baliwag, Bulacan',
    number: 'BP-001 / 2026',
  }, 'test-secret');
  const second = permitFingerprint({
    issuer: 'city hall',
    jurisdiction: 'Baliwag Bulacan',
    number: 'BP0012026',
  }, 'test-secret');

  assert.equal(first, second);
  assert.equal(first.length, 64);
});

test('permit fingerprint changes with issuer, jurisdiction, or secret', () => {
  const permit = { issuer: 'City Hall', jurisdiction: 'Baliwag, Bulacan', number: 'BP-001' };
  const first = permitFingerprint(permit, 'test-secret');

  assert.notEqual(permitFingerprint({ ...permit, issuer: 'DTI' }, 'test-secret'), first);
  assert.notEqual(permitFingerprint({ ...permit, jurisdiction: 'Malolos, Bulacan' }, 'test-secret'), first);
  assert.notEqual(permitFingerprint(permit, 'different-secret'), first);
});

test('legacy permit fingerprint ignores the unrecorded issuer', () => {
  const first = legacyPermitFingerprint({
    jurisdiction: 'Baliwag, Bulacan',
    number: 'BP-001 / 2026',
  }, 'test-secret');
  const second = legacyPermitFingerprint({
    jurisdiction: 'baliwag bulacan',
    number: 'BP0012026',
  }, 'test-secret');

  assert.equal(first, second);
});

test('rejects missing, blank, and overlong legal fields', () => {
  assert.throws(() => requiredText('', 'Permit number'), OrganizationRegistrationError);
  assert.throws(() => requiredText('   ', 'Permit number'), OrganizationRegistrationError);
  assert.throws(() => requiredText('x'.repeat(121), 'Permit number', 120), OrganizationRegistrationError);
});

test('only accepts permit documents hosted in the configured Cloudinary account', () => {
  assert.equal(
    validatePermitDocument('https://res.cloudinary.com/dfo5l4d4t/raw/upload/permit.pdf'),
    'https://res.cloudinary.com/dfo5l4d4t/raw/upload/permit.pdf',
  );
  assert.throws(
    () => validatePermitDocument('https://example.test/permit.pdf'),
    OrganizationRegistrationError,
  );
});

test('callable requires authentication before accessing Firestore', async () => {
  const handlers = createOrganizationHandlers({
    db: null,
    fieldValue: null,
    secret: 'test-secret',
  });

  await assert.rejects(
    handlers.submitApplication({}, {}),
    (error) => error.code === 'unauthenticated',
  );
});

test('callable validates required permit fields before accessing Firestore', async () => {
  const handlers = createOrganizationHandlers({
    db: null,
    fieldValue: null,
    secret: 'test-secret',
  });

  await assert.rejects(
    handlers.submitApplication({ permitIssuer: '' }, {
      auth: { uid: 'user-1', token: { email: 'user@example.test' } },
    }),
    (error) => error.code === 'invalid-argument',
  );
});

test('primary representative updates the pending application permit for review', async () => {
  const { db, documents } = createOrganizationDb(pendingOrganizationRecords());
  const handlers = createOrganizationHandlers({
    db,
    fieldValue: { serverTimestamp: () => 'server-time' },
    secret: 'test-secret',
  });
  const permitDocumentUrl = 'https://res.cloudinary.com/dfo5l4d4t/raw/upload/new.pdf';

  const result = await handlers.updateOrganizationPermit({
    organizationId: 'org-1',
    permitDocumentUrl,
  }, { auth: { uid: 'rep-1' } });

  assert.deepEqual(result, { status: 'pending_review' });
  assert.equal(
    documents.get('organizations/org-1/private/verification').permitDocumentUrl,
    permitDocumentUrl,
  );
  assert.equal(
    documents.get('users/rep-1').organizationPermitUrl,
    permitDocumentUrl,
  );
});

test('permit update rejects a user who is not the primary representative', async () => {
  const { db } = createOrganizationDb(pendingOrganizationRecords('other-user'));
  const handlers = createOrganizationHandlers({
    db,
    fieldValue: { serverTimestamp: () => 'server-time' },
    secret: 'test-secret',
  });

  await assert.rejects(
    handlers.updateOrganizationPermit({
      organizationId: 'org-1',
      permitDocumentUrl: 'https://res.cloudinary.com/dfo5l4d4t/raw/upload/new.pdf',
    }, { auth: { uid: 'other-user' } }),
    (error) => error.code === 'permission-denied',
  );
});

test('permit update rejects applications that are not pending', async () => {
  const records = pendingOrganizationRecords();
  records['organizations/org-1'].verificationStatus = 'verified';
  const { db } = createOrganizationDb(records);
  const handlers = createOrganizationHandlers({
    db,
    fieldValue: { serverTimestamp: () => 'server-time' },
    secret: 'test-secret',
  });

  await assert.rejects(
    handlers.updateOrganizationPermit({
      organizationId: 'org-1',
      permitDocumentUrl: 'https://res.cloudinary.com/dfo5l4d4t/raw/upload/new.pdf',
    }, { auth: { uid: 'rep-1' } }),
    (error) => error.code === 'failed-precondition',
  );
});

test('reviewer cannot approve an organization without a valid permit document', async () => {
  const records = pendingOrganizationRecords();
  records['organizationReviewers/reviewer-1'] = { enabled: true };
  records['organizations/org-1/private/verification'].permitDocumentUrl = '';
  const { db } = createOrganizationDb(records);
  const handlers = createOrganizationHandlers({
    db,
    auth: { getUser: async () => ({ emailVerified: true }) },
    fieldValue: { serverTimestamp: () => 'server-time' },
    secret: 'test-secret',
  });

  await assert.rejects(
    handlers.reviewApplication({
      organizationId: 'org-1',
      decision: 'verified',
    }, { auth: { uid: 'reviewer-1' } }),
    (error) => error.code === 'failed-precondition' && /permit/i.test(error.message),
  );
});