const crypto = require('node:crypto');

class OrganizationRegistrationError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function normalizeValue(value) {
  return String(value || '')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function requiredText(value, label, maxLength = 160) {
  if (typeof value !== 'string') {
    throw new OrganizationRegistrationError('invalid-argument', `${label} is required.`);
  }

  const result = value.trim();
  if (!result || result.length > maxLength) {
    throw new OrganizationRegistrationError('invalid-argument', `${label} is required and must be at most ${maxLength} characters.`);
  }
  return result;
}

function permitFingerprint({ issuer, jurisdiction, number }, secret) {
  if (!secret) {
    throw new OrganizationRegistrationError(
      'failed-precondition',
      'Organization registration is temporarily unavailable.',
    );
  }

  const identity = JSON.stringify([
    normalizeValue(issuer),
    normalizeValue(jurisdiction),
    normalizeValue(number).replace(/\s/g, ''),
  ]);

  return crypto.createHmac('sha256', secret).update(identity).digest('hex');
}

function legacyPermitFingerprint({ jurisdiction, number }, secret) {
  if (!secret) {
    throw new OrganizationRegistrationError(
      'failed-precondition',
      'Organization registration is temporarily unavailable.',
    );
  }

  const identity = JSON.stringify([
    normalizeValue(jurisdiction),
    normalizeValue(number).replace(/\s/g, ''),
  ]);
  return crypto.createHmac('sha256', secret).update(identity).digest('hex');
}

function validatePermitDocument(value) {
  try {
    const url = new URL(value);
    const pathSegments = url.pathname.split('/').filter(Boolean);
    if (
      url.protocol === 'https:' &&
      url.hostname === 'res.cloudinary.com' &&
      pathSegments[0] === 'dfo5l4d4t'
    ) {
      return url.toString();
    }
  } catch (_) {
    // Invalid URLs are rejected below.
  }

  throw new OrganizationRegistrationError(
    'invalid-argument',
    'Upload the organization permit before submitting.',
  );
}

function sanitizeAddress(value) {
  const address = value && typeof value === 'object' ? value : {};
  return {
    houseNumber: String(address.houseNumber || '').trim().slice(0, 80),
    sitioOrSubdivision: String(address.sitioOrSubdivision || '').trim().slice(0, 120),
    barangay: String(address.barangay || '').trim().slice(0, 120),
    city: String(address.city || '').trim().slice(0, 120),
    province: String(address.province || '').trim().slice(0, 120),
  };
}

function createOrganizationHandlers({ db, auth, fieldValue, secret }) {
  async function submitApplication(data, context) {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new OrganizationRegistrationError('unauthenticated', 'Sign in before submitting an organization request.');
    }

    const action = data?.action || 'register';
    if (!['register', 'requestRepresentative'].includes(action)) {
      throw new OrganizationRegistrationError('invalid-argument', 'Unsupported organization request.');
    }

    const issuer = requiredText(data.permitIssuer, 'Permit issuer', 120);
    const permitNumber = requiredText(data.permitNumber, 'Permit number', 120);
    const address = sanitizeAddress(data.addressDetails);
    const jurisdiction = [address.city, address.province].filter(Boolean).join(', ');
    if (!jurisdiction) {
      throw new OrganizationRegistrationError('invalid-argument', 'Organization city and province are required.');
    }

    const legalName = requiredText(data.legalName, 'Legal organization name', 160);
    const normalizedName = normalizeValue(legalName);
    const fingerprint = permitFingerprint(
      { issuer, jurisdiction, number: permitNumber },
      secret,
    );
    const legacyFingerprint = legacyPermitFingerprint(
      { jurisdiction, number: permitNumber },
      secret,
    );
    const permitDocumentUrl = action === 'register'
      ? validatePermitDocument(data.permitDocumentUrl)
      : null;
    const contactPerson = requiredText(data.contactPerson, 'Representative name', 120);
    const email = String(context.auth.token.email || '').trim().toLowerCase();

    if (!email) {
      throw new OrganizationRegistrationError('failed-precondition', 'A Firebase Auth email is required.');
    }

    const userRef = db.collection('users').doc(uid);
    const claimRef = db.collection('organizationRegistry').doc(fingerprint);
    const legacyClaimRef = db.collection('legacyOrganizationRegistry').doc(legacyFingerprint);
    const lookupRequestRef = db.collection('organizationMembershipRequests').doc(uid);
    const existingNameSnapshot = action === 'register'
      ? await db.collection('organizations')
        .where('normalizedName', '==', normalizedName)
        .limit(1)
        .get()
      : null;
    const possibleNameDuplicate = Boolean(existingNameSnapshot && !existingNameSnapshot.empty);

    return db.runTransaction(async (transaction) => {
      const [claimSnapshot, legacyClaimSnapshot, userSnapshot, lookupRequestSnapshot] = await Promise.all([
        transaction.get(claimRef),
        transaction.get(legacyClaimRef),
        transaction.get(userRef),
        transaction.get(lookupRequestRef),
      ]);

      const userData = userSnapshot.exists ? userSnapshot.data() : {};
      const currentMemberships = Array.isArray(userData.organizationMemberships)
        ? userData.organizationMemberships
        : [];

      if (claimSnapshot.exists || legacyClaimSnapshot.exists) {
        const existingClaim = claimSnapshot.exists
          ? claimSnapshot.data()
          : legacyClaimSnapshot.data();
        const organizationId = existingClaim.organizationId;
        const organizationRef = db.collection('organizations').doc(organizationId);
        const membershipRef = organizationRef.collection('members').doc(uid);
        const organizationSnapshot = await transaction.get(organizationRef);
        const membershipSnapshot = await transaction.get(membershipRef);

        if (!organizationSnapshot.exists) {
          throw new OrganizationRegistrationError('internal', 'The organization registry needs administrator review.');
        }

        const organization = organizationSnapshot.data();
        if (organization.verificationStatus === 'rejected') {
          throw new OrganizationRegistrationError('failed-precondition', 'This organization cannot accept new representative requests.');
        }

        const membershipStatus = membershipSnapshot.exists
          ? membershipSnapshot.data().status
          : 'pending';

        if (!claimSnapshot.exists) {
          transaction.create(claimRef, {
            organizationId,
            aliasFromLegacyRegistry: true,
            createdAt: fieldValue.serverTimestamp(),
          });
        }

        if (!membershipSnapshot.exists) {
          transaction.create(membershipRef, {
            uid,
            email,
            displayName: contactPerson,
            role: 'representative',
            status: 'pending',
            createdAt: fieldValue.serverTimestamp(),
            updatedAt: fieldValue.serverTimestamp(),
          });
        }

        const summary = {
          organizationId,
          organizationName: organization.legalName,
          organizationStatus: organization.verificationStatus,
          role: membershipSnapshot.exists
            ? membershipSnapshot.data().role
            : 'representative',
          status: membershipStatus,
        };
        const hasOtherActiveOrganization =
          userData.organizationStatus === 'verified' &&
          userData.organizationMembershipStatus === 'approved' &&
          userData.organizationId !== organizationId;

        transaction.set(userRef, {
          ...(!userSnapshot.exists
            ? {
                uid,
                name: action === 'register' ? organization.legalName : contactPerson,
                role: action === 'register' ? 'organization' : 'citizen',
                accountType: action === 'register' ? 'organization' : 'citizen',
                nameDetails: action === 'register'
                  ? { organizationName: organization.legalName }
                  : { firstName: contactPerson },
                createdAt: fieldValue.serverTimestamp(),
              }
            : {}),
          email,
          ...(!hasOtherActiveOrganization
            ? {
                organizationId,
                organizationStatus: organization.verificationStatus,
                organizationMembershipStatus: membershipStatus,
                activeOrganizationName: organization.legalName,
              }
            : {}),
          organizationRequestStatus: action === 'requestRepresentative'
            ? membershipStatus === 'approved'
              ? 'approved'
              : 'pending_review'
            : userData.organizationRequestStatus || null,
          organizationRequestName: action === 'requestRepresentative'
            ? organization.legalName
            : userData.organizationRequestName || null,
          ...(action === 'register'
            ? {
                organizationDetails: {
                  contactPerson,
                  businessPermitNumber: permitNumber,
                },
                organizationPermitUrl: permitDocumentUrl,
                phoneNumber: String(data.phoneNumber || '').trim(),
                addressDetails: address,
                isVerified: false,
              }
            : {}),
          organizationMemberships: [
            ...currentMemberships.filter((item) => item.organizationId !== organizationId),
            summary,
          ],
          updatedAt: fieldValue.serverTimestamp(),
        }, { merge: true });
        if (
          action === 'requestRepresentative' &&
          lookupRequestSnapshot.exists &&
          lookupRequestSnapshot.data().status === 'pending_lookup'
        ) {
          transaction.update(lookupRequestRef, {
            status: 'linked',
            organizationId,
            linkedAt: fieldValue.serverTimestamp(),
            updatedAt: fieldValue.serverTimestamp(),
          });
        }

        return { status: 'pending_review' };
      }

      if (action === 'requestRepresentative') {
        if (
          lookupRequestSnapshot.exists &&
          lookupRequestSnapshot.data().status === 'pending_lookup'
        ) {
          return { status: 'pending_review' };
        }
        transaction.set(lookupRequestRef, {
          uid,
          email,
          legalName,
          normalizedName,
          permitIssuer: issuer,
          permitNumber,
          jurisdiction,
          permitFingerprint: fingerprint,
          contactPerson,
          status: 'pending_lookup',
          createdAt: fieldValue.serverTimestamp(),
          updatedAt: fieldValue.serverTimestamp(),
        });
        transaction.set(userRef, {
          email,
          organizationRequestStatus: 'pending_review',
          organizationRequestName: legalName,
          updatedAt: fieldValue.serverTimestamp(),
        }, { merge: true });
        return { status: 'pending_review' };
      }

      const organizationRef = db.collection('organizations').doc();
      const membershipRef = organizationRef.collection('members').doc(uid);
      const verificationRef = organizationRef.collection('private').doc('verification');

      transaction.create(organizationRef, {
        legalName,
        normalizedName,
        verificationStatus: 'pending',
        reviewFlags: possibleNameDuplicate ? ['possible_name_duplicate'] : [],
        primaryRepresentativeUid: uid,
        representativeCount: 1,
        createdBy: uid,
        createdAt: fieldValue.serverTimestamp(),
        updatedAt: fieldValue.serverTimestamp(),
      });
      transaction.create(verificationRef, {
        permitIssuer: issuer,
        permitNumber,
        jurisdiction,
        permitFingerprint: fingerprint,
        permitDocumentUrl,
        submittedBy: uid,
        submittedAt: fieldValue.serverTimestamp(),
      });
      transaction.create(membershipRef, {
        uid,
        email,
        displayName: contactPerson,
        role: 'primary_representative',
        status: 'pending',
        createdAt: fieldValue.serverTimestamp(),
        updatedAt: fieldValue.serverTimestamp(),
      });
      transaction.create(claimRef, {
        organizationId: organizationRef.id,
        createdAt: fieldValue.serverTimestamp(),
      });

      const summary = {
        organizationId: organizationRef.id,
        activeOrganizationName: legalName,
        organizationName: legalName,
        organizationStatus: 'pending',
        role: 'primary_representative',
        status: 'pending',
      };
      transaction.set(userRef, {
        uid,
        name: legalName,
        email,
        role: 'organization',
        accountType: 'organization',
        nameDetails: { organizationName: legalName },
        organizationDetails: { contactPerson, businessPermitNumber: permitNumber },
        organizationPermitUrl: permitDocumentUrl,
        organizationId: organizationRef.id,
        activeOrganizationName: legalName,
        organizationStatus: 'pending',
        organizationMembershipStatus: 'pending',
        organizationMemberships: [
          ...currentMemberships.filter((item) => item.organizationId !== organizationRef.id),
          summary,
        ],
        phoneNumber: String(data.phoneNumber || '').trim(),
        addressDetails: address,
        isVerified: false,
        updatedAt: fieldValue.serverTimestamp(),
        ...(!userSnapshot.exists ? { createdAt: fieldValue.serverTimestamp() } : {}),
      }, { merge: true });

      return { status: 'pending_review' };
    });
  }

  async function reviewApplication(data, context) {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new OrganizationRegistrationError('unauthenticated', 'Sign in with an administrator account.');
    }

    const organizationId = requiredText(data?.organizationId, 'Organization ID', 200);
    const decision = data?.decision;
    if (!['verified', 'rejected'].includes(decision)) {
      throw new OrganizationRegistrationError('invalid-argument', 'Decision must be verified or rejected.');
    }

    const adminSnapshot = await db.collection('organizationReviewers').doc(uid).get();
    if (!adminSnapshot.exists || adminSnapshot.data().enabled !== true) {
      throw new OrganizationRegistrationError('permission-denied', 'You cannot review organization applications.');
    }

    const organizationRef = db.collection('organizations').doc(organizationId);
    const organizationForReview = await organizationRef.get();
    if (!organizationForReview.exists) {
      throw new OrganizationRegistrationError('not-found', 'Organization application not found.');
    }
    const representativeUid = data.representativeUid ||
      organizationForReview.data().primaryRepresentativeUid;
    const representativeAccount = await auth.getUser(representativeUid);
    if (decision === 'verified' && !representativeAccount.emailVerified) {
      throw new OrganizationRegistrationError(
        'failed-precondition',
        'The representative must verify their sign-in email before approval.',
      );
    }

    return db.runTransaction(async (transaction) => {
      const organizationSnapshot = await transaction.get(organizationRef);
      if (!organizationSnapshot.exists) {
        throw new OrganizationRegistrationError('not-found', 'Organization application not found.');
      }

      const organization = organizationSnapshot.data();
      const status = decision === 'verified' ? 'verified' : 'rejected';
      const requestedRepresentativeUid = data.representativeUid;

      if (requestedRepresentativeUid) {
        if (organization.verificationStatus !== 'verified') {
          throw new OrganizationRegistrationError('failed-precondition', 'Verify the organization before approving representatives.');
        }
        const memberRef = organizationRef.collection('members').doc(requestedRepresentativeUid);
        const userRef = db.collection('users').doc(requestedRepresentativeUid);
        const [memberSnapshot, userSnapshot] = await Promise.all([
          transaction.get(memberRef),
          transaction.get(userRef),
        ]);
        if (!memberSnapshot.exists || memberSnapshot.data().status !== 'pending') {
          throw new OrganizationRegistrationError('failed-precondition', 'No pending representative request was found.');
        }

        transaction.update(memberRef, {
          status: status === 'verified' ? 'approved' : 'rejected',
          reviewedBy: uid,
          reviewedAt: fieldValue.serverTimestamp(),
          updatedAt: fieldValue.serverTimestamp(),
        });
        if (userSnapshot.exists) {
          const userData = userSnapshot.data();
          const memberships = Array.isArray(userData.organizationMemberships)
            ? userData.organizationMemberships
            : [];
          const hasOtherApprovedOrganization =
            decision === 'rejected' &&
            userData.organizationStatus === 'verified' &&
            userData.organizationMembershipStatus === 'approved' &&
            userData.organizationId !== organizationId;
          transaction.update(userRef, {
            ...(!hasOtherApprovedOrganization
              ? {
                  organizationMembershipStatus: status === 'verified' ? 'approved' : 'rejected',
                  organizationId,
                  activeOrganizationName: organization.legalName,
                  organizationStatus: 'verified',
                }
              : {}),
            organizationRequestStatus: status === 'verified' ? 'approved' : 'rejected',
            organizationMemberships: memberships.map((item) => item.organizationId === organizationId
              ? { ...item, organizationStatus: 'verified', status: status === 'verified' ? 'approved' : 'rejected' }
              : item),
            updatedAt: fieldValue.serverTimestamp(),
          });
        }
        return { status: status === 'verified' ? 'approved' : 'rejected' };
      }

      if (organization.verificationStatus !== 'pending') {
        throw new OrganizationRegistrationError('failed-precondition', 'This application has already been reviewed.');
      }

      const primaryUid = organization.primaryRepresentativeUid;
      const primaryMembershipRef = organizationRef.collection('members').doc(primaryUid);
      const verificationRef = organizationRef.collection('private').doc('verification');
      const primaryUserRef = db.collection('users').doc(primaryUid);
      const [verificationSnapshot, membershipSnapshot, userSnapshot] = await Promise.all([
        transaction.get(verificationRef),
        transaction.get(primaryMembershipRef),
        transaction.get(primaryUserRef),
      ]);

      if (decision === 'verified') {
        try {
          validatePermitDocument(
            verificationSnapshot.exists
              ? verificationSnapshot.data().permitDocumentUrl
              : null,
          );
        } catch (_) {
          throw new OrganizationRegistrationError(
            'failed-precondition',
            'A valid business permit must be attached before approval.',
          );
        }
      }

      transaction.update(organizationRef, {
        verificationStatus: status,
        reviewedBy: uid,
        reviewedAt: fieldValue.serverTimestamp(),
        updatedAt: fieldValue.serverTimestamp(),
      });
      if (membershipSnapshot.exists) {
        transaction.update(primaryMembershipRef, {
          status: status === 'verified' ? 'approved' : 'rejected',
          reviewedBy: uid,
          reviewedAt: fieldValue.serverTimestamp(),
          updatedAt: fieldValue.serverTimestamp(),
        });
      }
      if (userSnapshot.exists) {
        const userData = userSnapshot.data();
        const memberships = Array.isArray(userData.organizationMemberships)
          ? userData.organizationMemberships
          : [];
        transaction.update(primaryUserRef, {
          organizationStatus: status,
          organizationMembershipStatus: status === 'verified' ? 'approved' : 'rejected',
          organizationMemberships: memberships.map((item) => item.organizationId === organizationId
            ? { ...item, organizationStatus: status, status: status === 'verified' ? 'approved' : 'rejected' }
            : item),
          updatedAt: fieldValue.serverTimestamp(),
        });
      }

      return { status };
    });
  }

  async function updateOrganizationPermit(data, context) {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new OrganizationRegistrationError(
        'unauthenticated',
        'Sign in before updating an organization permit.',
      );
    }

    const organizationId = requiredText(data?.organizationId, 'Organization ID', 200);
    const permitDocumentUrl = validatePermitDocument(data?.permitDocumentUrl);
    const organizationRef = db.collection('organizations').doc(organizationId);
    const memberRef = organizationRef.collection('members').doc(uid);
    const verificationRef = organizationRef.collection('private').doc('verification');
    const userRef = db.collection('users').doc(uid);

    return db.runTransaction(async (transaction) => {
      const [organizationSnapshot, memberSnapshot, verificationSnapshot, userSnapshot] = await Promise.all([
        transaction.get(organizationRef),
        transaction.get(memberRef),
        transaction.get(verificationRef),
        transaction.get(userRef),
      ]);

      if (!organizationSnapshot.exists) {
        throw new OrganizationRegistrationError('not-found', 'Organization application not found.');
      }

      const organization = organizationSnapshot.data();
      if (organization.primaryRepresentativeUid !== uid) {
        throw new OrganizationRegistrationError(
          'permission-denied',
          'Only the primary representative can update this permit.',
        );
      }
      if (organization.verificationStatus !== 'pending') {
        throw new OrganizationRegistrationError(
          'failed-precondition',
          'Only pending organization applications can update their permit.',
        );
      }
      if (
        !memberSnapshot.exists ||
        memberSnapshot.data().role !== 'primary_representative' ||
        memberSnapshot.data().status !== 'pending'
      ) {
        throw new OrganizationRegistrationError(
          'permission-denied',
          'A pending primary representative membership is required.',
        );
      }
      if (!verificationSnapshot.exists) {
        throw new OrganizationRegistrationError(
          'failed-precondition',
          'The organization permit record is unavailable.',
        );
      }

      const timestamp = fieldValue.serverTimestamp();
      transaction.update(verificationRef, {
        permitDocumentUrl,
        permitUpdatedBy: uid,
        permitUpdatedAt: timestamp,
      });
      transaction.update(organizationRef, { updatedAt: timestamp });
      if (userSnapshot.exists && userSnapshot.data().organizationId === organizationId) {
        transaction.update(userRef, {
          organizationPermitUrl: permitDocumentUrl,
          updatedAt: timestamp,
        });
      }

      return { status: 'pending_review' };
    });
  }

  async function listPendingApplications(context) {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new OrganizationRegistrationError('unauthenticated', 'Sign in with an administrator account.');
    }
    const reviewerSnapshot = await db.collection('organizationReviewers').doc(uid).get();
    if (!reviewerSnapshot.exists || reviewerSnapshot.data().enabled !== true) {
      throw new OrganizationRegistrationError('permission-denied', 'You cannot review organization applications.');
    }

    const organizationsSnapshot = await db.collection('organizations')
      .where('verificationStatus', '==', 'pending')
      .get();
    const representativesSnapshot = await db.collectionGroup('members')
      .where('status', '==', 'pending')
      .limit(100)
      .get();
    const lookupRequestsSnapshot = await db.collection('organizationMembershipRequests')
      .where('status', '==', 'pending_lookup')
      .limit(50)
      .get();

    const pendingOrganizationDocs = organizationsSnapshot.docs
      .sort((left, right) => {
        const leftTime = left.data().createdAt?.toMillis?.() || 0;
        const rightTime = right.data().createdAt?.toMillis?.() || 0;
        return rightTime - leftTime;
      })
      .slice(0, 50);
    const applications = await Promise.all(pendingOrganizationDocs.map(async (document) => {
      const organization = document.data();
      const verificationSnapshot = await document.ref.collection('private').doc('verification').get();
      const verification = verificationSnapshot.exists ? verificationSnapshot.data() : {};
      const representativeUid = organization.primaryRepresentativeUid || '';
      const [representativeAccount, representativeProfile] = representativeUid
        ? await Promise.all([
            auth.getUser(representativeUid).catch(() => null),
            db.collection('users').doc(representativeUid).get(),
          ])
        : [null, null];
      const representativeData = representativeProfile?.exists
        ? representativeProfile.data()
        : {};
      return {
        organizationId: document.id,
        legalName: organization.legalName,
        verificationStatus: organization.verificationStatus,
        reviewFlags: organization.reviewFlags || [],
        primaryRepresentativeUid: representativeUid,
        primaryRepresentativeName:
          representativeData.organizationDetails?.contactPerson ||
          representativeData.contactPerson || '',
        primaryRepresentativeEmail:
          representativeAccount?.email || representativeData.email || '',
        primaryRepresentativeEmailVerified:
          representativeAccount?.emailVerified === true,
        permitIssuer: verification.permitIssuer || '',
        permitNumber: verification.permitNumber || '',
        jurisdiction: verification.jurisdiction || '',
        permitDocumentUrl: verification.permitDocumentUrl || '',
      };
    }));

    const representativeRequests = await Promise.all(
      representativesSnapshot.docs.map(async (document) => {
        const organizationRef = document.ref.parent.parent;
        if (!organizationRef) return null;
        const organizationSnapshot = await organizationRef.get();
        if (!organizationSnapshot.exists) return null;
        const organization = organizationSnapshot.data();
        if (organization.verificationStatus !== 'verified') return null;
        const member = document.data();
        const representativeAccount = member.uid
          ? await auth.getUser(member.uid).catch(() => null)
          : null;
        return {
          organizationId: organizationRef.id,
          organizationName: organization.legalName,
          representativeUid: member.uid,
          representativeName: member.displayName || '',
          email: member.email || '',
          emailVerified: representativeAccount?.emailVerified === true,
        };
      }),
    );

    const unmatchedRequests = lookupRequestsSnapshot.docs.map((document) => {
      const request = document.data();
      return {
        requestId: document.id,
        uid: request.uid,
        email: request.email || '',
        legalName: request.legalName || '',
        permitIssuer: request.permitIssuer || '',
        permitNumber: request.permitNumber || '',
        jurisdiction: request.jurisdiction || '',
        status: request.status,
      };
    });

    return {
      applications,
      representativeRequests: representativeRequests.filter(Boolean),
      unmatchedRequests,
    };
  }

  async function rejectLookupRequest(data, context) {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new OrganizationRegistrationError('unauthenticated', 'Sign in with an administrator account.');
    }
    const requestId = requiredText(data?.requestId, 'Request ID', 200);
    const reviewerSnapshot = await db.collection('organizationReviewers').doc(uid).get();
    if (!reviewerSnapshot.exists || reviewerSnapshot.data().enabled !== true) {
      throw new OrganizationRegistrationError('permission-denied', 'You cannot review organization requests.');
    }

    const requestRef = db.collection('organizationMembershipRequests').doc(requestId);
    return db.runTransaction(async (transaction) => {
      const requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists || requestSnapshot.data().status !== 'pending_lookup') {
        throw new OrganizationRegistrationError('not-found', 'Pending request not found.');
      }

      const request = requestSnapshot.data();
      const userRef = db.collection('users').doc(request.uid);
      const userSnapshot = await transaction.get(userRef);
      transaction.update(requestRef, {
        status: 'rejected',
        reviewedBy: uid,
        reviewedAt: fieldValue.serverTimestamp(),
        updatedAt: fieldValue.serverTimestamp(),
      });
      if (userSnapshot.exists) {
        transaction.update(userRef, {
          organizationRequestStatus: 'rejected',
          updatedAt: fieldValue.serverTimestamp(),
        });
      }
      return { status: 'rejected' };
    });
  }

  return {
    submitApplication,
    reviewApplication,
    updateOrganizationPermit,
    listPendingApplications,
    rejectLookupRequest,
  };
}

module.exports = {
  OrganizationRegistrationError,
  createOrganizationHandlers,
  normalizeValue,
  legacyPermitFingerprint,
  permitFingerprint,
  requiredText,
  validatePermitDocument,
};