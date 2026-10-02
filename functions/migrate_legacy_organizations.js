const admin = require('firebase-admin');
const {
  legacyPermitFingerprint,
  normalizeValue,
  permitFingerprint,
} = require('./organization_registration');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'cenro-4b48e';
const LEGACY_ISSUER = 'Legacy issuer not recorded';
const isApply = process.argv.includes('--apply');
const secret = process.env.ORG_REGISTRY_HMAC_KEY;

if (!secret) {
  console.error('Set ORG_REGISTRY_HMAC_KEY to the same secret used by deployed functions.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: PROJECT_ID,
});

const db = admin.firestore();
const fieldValue = admin.firestore.FieldValue;

function legacyDetails(data) {
  const organizationDetails = data.organizationDetails || {};
  const nameDetails = data.nameDetails || {};
  const address = data.addressDetails || {};
  const permitNumber = data.businessPermitNumber ||
    organizationDetails.businessPermitNumber || '';
  const city = String(address.city || '').trim();
  const province = String(address.province || '').trim();
  const legalName = String(nameDetails.organizationName || data.name || '').trim();

  if (!permitNumber || !city || !province || !legalName) return null;
  return {
    permitNumber: String(permitNumber).trim(),
    jurisdiction: [city, province].join(', '),
    legalName,
    normalizedName: normalizeValue(legalName),
    permitDocumentUrl: data.organizationPermitUrl || data.businessPermitUrl || null,
    contactPerson: String(
      organizationDetails.contactPerson || data.contactPerson || '',
    ).trim(),
  };
}

async function migrateGroup(fingerprint, records) {
  const deterministicId = `legacy_${fingerprint}`;
  const legacyClaimRef = db.collection('legacyOrganizationRegistry').doc(fingerprint);
  const exactFingerprint = permitFingerprint({
    issuer: LEGACY_ISSUER,
    jurisdiction: records[0].details.jurisdiction,
    number: records[0].details.permitNumber,
  }, secret);
  const exactClaimRef = db.collection('organizationRegistry').doc(exactFingerprint);

  return db.runTransaction(async (transaction) => {
    const [legacyClaimSnapshot, exactClaimSnapshot] = await Promise.all([
      transaction.get(legacyClaimRef),
      transaction.get(exactClaimRef),
    ]);

    const organizationId = exactClaimSnapshot.exists
      ? exactClaimSnapshot.data().organizationId
      : deterministicId;
    const organizationRef = db.collection('organizations').doc(organizationId);
    const verificationRef = organizationRef.collection('private').doc('verification');
    const memberRefs = records.map((record) =>
      organizationRef.collection('members').doc(record.uid),
    );
    const userRefs = records.map((record) => db.collection('users').doc(record.uid));
    const snapshots = await Promise.all([
      transaction.get(organizationRef),
      transaction.get(verificationRef),
      ...memberRefs.map((ref) => transaction.get(ref)),
      ...userRefs.map((ref) => transaction.get(ref)),
    ]);

    if (legacyClaimSnapshot.exists && snapshots[0].exists) return false;

    let snapshotIndex = 2;
    const memberSnapshots = snapshots.slice(snapshotIndex, snapshotIndex + records.length);
    snapshotIndex += records.length;
    const userSnapshots = snapshots.slice(snapshotIndex);
    const primaryUid = records[0].uid;
    const firstDetails = records[0].details;

    if (!snapshots[0].exists) {
      transaction.create(organizationRef, {
        legalName: firstDetails.legalName,
        normalizedName: firstDetails.normalizedName,
        verificationStatus: 'pending',
        reviewFlags: [
          'legacy_import',
          ...(records.length > 1 ? ['multiple_legacy_accounts'] : []),
        ],
        primaryRepresentativeUid: primaryUid,
        representativeCount: records.length,
        createdBy: primaryUid,
        createdAt: fieldValue.serverTimestamp(),
        updatedAt: fieldValue.serverTimestamp(),
      });
    }

    if (!snapshots[1].exists) {
      transaction.create(verificationRef, {
        permitIssuer: LEGACY_ISSUER,
        permitNumber: firstDetails.permitNumber,
        jurisdiction: firstDetails.jurisdiction,
        permitFingerprint: exactFingerprint,
        permitDocumentUrl: firstDetails.permitDocumentUrl,
        submittedBy: primaryUid,
        submittedAt: fieldValue.serverTimestamp(),
      });
    }

    if (!legacyClaimSnapshot.exists) {
      transaction.create(legacyClaimRef, {
        organizationId,
        createdAt: fieldValue.serverTimestamp(),
      });
    }
    if (!exactClaimSnapshot.exists) {
      transaction.create(exactClaimRef, {
        organizationId,
        legacyIssuerUnknown: true,
        createdAt: fieldValue.serverTimestamp(),
      });
    }

    records.forEach((record, index) => {
      const memberStatus = memberSnapshots[index].exists
        ? memberSnapshots[index].data().status
        : 'pending';
      if (!memberSnapshots[index].exists) {
        transaction.create(memberRefs[index], {
          uid: record.uid,
          email: record.data.email || '',
          displayName: record.details.contactPerson || record.data.name || '',
          role: index === 0 ? 'primary_representative' : 'representative',
          status: 'pending',
          createdAt: fieldValue.serverTimestamp(),
          updatedAt: fieldValue.serverTimestamp(),
        });
      }

      const userData = userSnapshots[index].exists
        ? userSnapshots[index].data()
        : {};
      const memberships = Array.isArray(userData.organizationMemberships)
        ? userData.organizationMemberships.filter((item) => item.organizationId !== organizationId)
        : [];
      transaction.set(userRefs[index], {
        organizationId,
        activeOrganizationName: firstDetails.legalName,
        organizationStatus: 'pending',
        organizationMembershipStatus: memberStatus,
        organizationMemberships: [
          ...memberships,
          {
            organizationId,
            organizationName: firstDetails.legalName,
            organizationStatus: 'pending',
            role: index === 0 ? 'primary_representative' : 'representative',
            status: memberStatus,
          },
        ],
        updatedAt: fieldValue.serverTimestamp(),
      }, { merge: true });
    });

    return true;
  });
}

async function main() {
  const snapshot = await db.collection('users')
    .where('role', '==', 'organization')
    .get();
  const groups = new Map();
  let skipped = 0;

  snapshot.docs.forEach((document) => {
    const details = legacyDetails(document.data());
    if (!details) {
      skipped += 1;
      return;
    }
    const fingerprint = legacyPermitFingerprint({
      jurisdiction: details.jurisdiction,
      number: details.permitNumber,
    }, secret);
    const group = groups.get(fingerprint) || [];
    group.push({ uid: document.id, data: document.data(), details });
    groups.set(fingerprint, group);
  });

  console.log(`${isApply ? 'Applying' : 'Dry run:'} ${groups.size} organization groups; ${skipped} records need manual data repair.`);
  for (const [fingerprint, records] of groups) {
    const maskedPermit = records[0].details.permitNumber.slice(-4).padStart(4, '*');
    console.log(`- ${records[0].details.legalName}; ${records[0].details.jurisdiction}; permit ending ${maskedPermit}; representatives ${records.length}`);
    if (isApply) await migrateGroup(fingerprint, records);
  }

  if (!isApply) console.log('No data changed. Re-run with --apply after reviewing the groups.');
}

main().then(() => process.exit(0)).catch((error) => {
  console.error('Legacy organization migration failed:', error);
  process.exit(1);
});