import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "jose";

const FIREBASE_JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);
const OAUTH_TOKEN_URL = "https://oauth2.googleapis.com/token";
const AUTH_LOOKUP_URL = "https://identitytoolkit.googleapis.com/v1/projects";
const FIRESTORE_API_URL = "https://firestore.googleapis.com/v1/projects";
const SERVER_TIMESTAMP = { setToServerValue: "REQUEST_TIME" };
const ADMIN_ROLE_ALIASES = new Set([
  "admin",
  "super_admin",
  "system_admin",
  "administrator",
  "sysadmin",
]);

export class OrganizationApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export function isOrganizationAdminRole(role) {
  return ADMIN_ROLE_ALIASES.has(
    String(role || "").trim().toLowerCase().replace(/[\s-]+/g, "_"),
  );
}

function apiError(status, code, message) {
  return new OrganizationApiError(status, code, message);
}

function cleanString(value, label, maxLength = 200) {
  if (typeof value !== "string" || !value.trim() || value.trim().length > maxLength) {
    throw apiError(400, "invalid-argument", `${label} is required.`);
  }
  return value.trim();
}

function projectIdFromEnv(env) {
  const projectId = String(env.FIREBASE_PROJECT_ID || "").trim();
  if (!projectId) throw apiError(503, "failed-precondition", "Firebase project configuration is missing.");
  return projectId;
}

function normalizeRegistryValue(value) {
  return String(value || "")
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

async function registryFingerprint(parts, secret) {
  if (!secret) {
    throw apiError(503, "failed-precondition", "Organization registry HMAC secret is not configured on the Worker.");
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(JSON.stringify(parts)),
  );
  return Array.from(new Uint8Array(signature), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function organizationPermitFingerprints({ issuer, jurisdiction, number }, secret) {
  const normalizedNumber = normalizeRegistryValue(number).replace(/\s/g, "");
  const exact = await registryFingerprint([
    normalizeRegistryValue(issuer),
    normalizeRegistryValue(jurisdiction),
    normalizedNumber,
  ], secret);
  const legacy = await registryFingerprint([
    normalizeRegistryValue(jurisdiction),
    normalizedNumber,
  ], secret);
  return { exact, legacy };
}

function documentName(projectId, path) {
  const segments = path.split("/").filter(Boolean).map(encodeURIComponent);
  return `projects/${projectId}/databases/(default)/documents/${segments.join("/")}`;
}

function documentsUrl(projectId, suffix = "") {
  return `${FIRESTORE_API_URL}/${encodeURIComponent(projectId)}/databases/(default)/documents${suffix}`;
}

function encodeFirestoreValue(value) {
  if (value === null) return { nullValue: "NULL_VALUE" };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeFirestoreValue) } };
  }
  if (typeof value === "object") {
    return { mapValue: { fields: encodeFirestoreFields(value) } };
  }
  return { nullValue: "NULL_VALUE" };
}

function encodeFirestoreFields(fields) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, encodeFirestoreValue(value)]),
  );
}

function decodeFirestoreValue(value) {
  if (Object.hasOwn(value, "stringValue")) return value.stringValue;
  if (Object.hasOwn(value, "booleanValue")) return value.booleanValue;
  if (Object.hasOwn(value, "integerValue")) return Number(value.integerValue);
  if (Object.hasOwn(value, "doubleValue")) return value.doubleValue;
  if (Object.hasOwn(value, "timestampValue")) return value.timestampValue;
  if (Object.hasOwn(value, "nullValue")) return null;
  if (value.arrayValue) return (value.arrayValue.values || []).map(decodeFirestoreValue);
  if (value.mapValue) return decodeFirestoreFields(value.mapValue.fields || {});
  return undefined;
}

function decodeFirestoreFields(fields = {}) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, decodeFirestoreValue(value)]),
  );
}

function decodeDocument(document) {
  if (!document) return null;
  return {
    path: document.name.split("/documents/")[1],
    updateTime: document.updateTime,
    createTime: document.createTime,
    data: decodeFirestoreFields(document.fields),
  };
}

async function authorizedFetch(url, accessToken, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      ...(options.body ? { "Content-Type": "application/json" } : {}),
      ...options.headers,
    },
  });
  if (!response.ok) {
    const message = await response.text().catch(() => "");
    throw new OrganizationApiError(
      response.status === 404 ? 404 : response.status >= 500 ? 502 : response.status,
      response.status === 404 ? "not-found" : "upstream-error",
      `Firebase API request failed (${response.status}): ${message.slice(0, 500)}`,
    );
  }
  return response;
}

async function getGoogleAccessToken(env) {
  let serviceAccount;
  try {
    serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON || "");
  } catch {
    throw apiError(503, "failed-precondition", "Firebase service credentials are not configured.");
  }
  if (!serviceAccount.client_email || !serviceAccount.private_key) {
    throw apiError(503, "failed-precondition", "Firebase service credentials are incomplete.");
  }
  if (serviceAccount.project_id !== projectIdFromEnv(env)) {
    throw apiError(503, "failed-precondition", "Firebase service credentials target a different project.");
  }

  const privateKey = await importPKCS8(serviceAccount.private_key, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/cloud-platform",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(serviceAccount.client_email)
    .setAudience(OAUTH_TOKEN_URL)
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(privateKey);

  const response = await fetch(OAUTH_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw apiError(502, "upstream-error", "Could not obtain Firebase service access.");
  }
  const tokenResponse = await response.json();
  if (!tokenResponse.access_token) {
    throw apiError(502, "upstream-error", "Firebase did not return a service access token.");
  }
  return tokenResponse.access_token;
}

async function verifyFirebaseIdToken(request, env) {
  const authorization = request.headers.get("Authorization") || "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice(7).trim() : "";
  if (!token) throw apiError(401, "unauthenticated", "Sign in to continue.");

  const projectId = projectIdFromEnv(env);
  let payload;
  try {
    ({ payload } = await jwtVerify(token, FIREBASE_JWKS, {
      issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId,
      maxTokenAge: "1h",
    }));
  } catch {
    throw apiError(401, "unauthenticated", "Your sign-in session is invalid or expired. Sign in again.");
  }

  const uid = typeof payload.sub === "string" ? payload.sub : "";
  const authTime = Number(payload.auth_time);
  if (!uid || !Number.isFinite(authTime) || authTime > Math.floor(Date.now() / 1000)) {
    throw apiError(401, "unauthenticated", "Your sign-in session is invalid. Sign in again.");
  }
  return uid;
}

async function batchGetDocuments(projectId, accessToken, paths) {
  const uniquePaths = [...new Set(paths.filter(Boolean))];
  if (uniquePaths.length === 0) return new Map();
  const response = await authorizedFetch(
    documentsUrl(projectId, ":batchGet"),
    accessToken,
    {
      method: "POST",
      body: JSON.stringify({ documents: uniquePaths.map((path) => documentName(projectId, path)) }),
    },
  );
  const rows = await response.json();
  const documents = new Map();
  for (const row of rows) {
    if (row.found) {
      const document = decodeDocument(row.found);
      documents.set(document.path, document);
    }
  }
  return documents;
}

async function queryDocuments(projectId, accessToken, collectionId, field, value, limit, allDescendants = false) {
  const structuredQuery = {
    from: [{ collectionId, ...(allDescendants ? { allDescendants: true } : {}) }],
    where: {
      fieldFilter: {
        field: { fieldPath: field },
        op: "EQUAL",
        value: encodeFirestoreValue(value),
      },
    },
    limit,
  };
  const response = await authorizedFetch(
    documentsUrl(projectId, ":runQuery"),
    accessToken,
    {
      method: "POST",
      body: JSON.stringify({ structuredQuery }),
    },
  );
  const rows = await response.json();
  return rows.map((row) => decodeDocument(row.document)).filter(Boolean);
}

async function lookupAuthUsers(projectId, accessToken, uids) {
  const localIds = [...new Set(uids.filter(Boolean))].slice(0, 100);
  if (!localIds.length) return new Map();
  const response = await authorizedFetch(
    `${AUTH_LOOKUP_URL}/${encodeURIComponent(projectId)}/accounts:lookup`,
    accessToken,
    { method: "POST", body: JSON.stringify({ localId: localIds }) },
  );
  const result = await response.json();
  return new Map((result.users || []).map((user) => [user.localId, user]));
}

async function commitUpdates(projectId, accessToken, updates) {
  const writes = updates.map(({ path, updateTime, exists, fields, transforms = [] }) => ({
    update: {
      name: documentName(projectId, path),
      fields: encodeFirestoreFields(fields),
    },
    updateMask: { fieldPaths: Object.keys(fields) },
    ...(transforms.length
      ? { updateTransforms: transforms.map((fieldPath) => ({ fieldPath, ...SERVER_TIMESTAMP })) }
      : {}),
    currentDocument: updateTime
      ? { updateTime }
      : { exists: exists === true },
  }));
  if (!writes.length) return;
  await authorizedFetch(documentsUrl(projectId, ":commit"), accessToken, {
    method: "POST",
    body: JSON.stringify({ writes }),
  });
}

async function authenticateReviewer(request, env) {
  const uid = await verifyFirebaseIdToken(request, env);
  const projectId = projectIdFromEnv(env);
  const accessToken = await getGoogleAccessToken(env);
  const records = await batchGetDocuments(projectId, accessToken, [
    `users/${uid}`,
    `organizationReviewers/${uid}`,
  ]);
  const profile = records.get(`users/${uid}`)?.data;
  const reviewer = records.get(`organizationReviewers/${uid}`)?.data;
  if (!isOrganizationAdminRole(profile?.role)) {
    throw apiError(403, "permission-denied", "An admin account is required for organization reviews.");
  }
  if (reviewer?.enabled !== true) {
    throw apiError(
      403,
      "permission-denied",
      "This admin account is not enabled for organization reviews. Enable organizationReviewers/{uid}.enabled for this account.",
    );
  }
  return { uid, projectId, accessToken };
}

async function authenticateApplicant(request, env) {
  const uid = await verifyFirebaseIdToken(request, env);
  const projectId = projectIdFromEnv(env);
  const accessToken = await getGoogleAccessToken(env);
  const authUsers = await lookupAuthUsers(projectId, accessToken, [uid]);
  const authUser = authUsers.get(uid);
  if (!authUser?.email) {
    throw apiError(412, "failed-precondition", "A Firebase Auth email is required to submit an organization application.");
  }
  return {
    uid,
    projectId,
    accessToken,
    email: String(authUser.email).trim().toLowerCase(),
  };
}

function cloudinaryPermitUrl(value, env) {
  const cloudName = String(env.CLOUDINARY_CLOUD_NAME || "").trim();
  try {
    const url = new URL(value);
    const segments = url.pathname.split("/").filter(Boolean);
    if (
      cloudName &&
      url.protocol === "https:" &&
      url.hostname === "res.cloudinary.com" &&
      segments[0] === cloudName
    ) return url.toString();
  } catch {
    // Invalid or missing URLs are rejected below.
  }
  throw apiError(412, "failed-precondition", "A valid business permit must be attached before approval.");
}

function membershipStatusList(userData, organizationId, organizationStatus, status) {
  const memberships = Array.isArray(userData.organizationMemberships)
    ? userData.organizationMemberships
    : [];
  return memberships.map((item) => item.organizationId === organizationId
    ? { ...item, organizationStatus, status }
    : item);
}

function sanitizedAddress(value) {
  const address = value && typeof value === "object" ? value : {};
  return {
    houseNumber: String(address.houseNumber || "").trim().slice(0, 80),
    sitioOrSubdivision: String(address.sitioOrSubdivision || "").trim().slice(0, 120),
    barangay: String(address.barangay || "").trim().slice(0, 120),
    city: cleanString(address.city, "Organization city", 120),
    province: cleanString(address.province, "Organization province", 120),
  };
}

function serverTimestampUpdate(fields, updateTime, exists) {
  return {
    fields,
    ...(updateTime ? { updateTime } : { exists: exists === true }),
    transforms: ["updatedAt"],
  };
}

async function submitOrganizationApplication(body, applicant, env) {
  const action = body.action || "register";
  if (!["register", "requestRepresentative"].includes(action)) {
    throw apiError(400, "invalid-argument", "Unsupported organization request.");
  }

  const legalName = cleanString(body.legalName, "Legal organization name", 160);
  const normalizedName = normalizeRegistryValue(legalName);
  const permitIssuer = cleanString(body.permitIssuer, "Permit issuer", 120);
  const permitNumber = cleanString(body.permitNumber, "Permit number", 120);
  const contactPerson = cleanString(body.contactPerson, "Authorized contact person", 120);
  const address = sanitizedAddress(body.addressDetails);
  const jurisdiction = `${address.city}, ${address.province}`;
  const permitFingerprints = await organizationPermitFingerprints(
    { issuer: permitIssuer, jurisdiction, number: permitNumber },
    env.ORG_REGISTRY_HMAC_KEY,
  );
  const permitDocumentUrl = action === "register"
    ? cloudinaryPermitUrl(body.permitDocumentUrl, env)
    : null;
  const { uid, projectId, accessToken, email } = applicant;
  const userPath = `users/${uid}`;
  const claimPath = `organizationRegistry/${permitFingerprints.exact}`;
  const legacyClaimPath = `legacyOrganizationRegistry/${permitFingerprints.legacy}`;
  const lookupPath = `organizationMembershipRequests/${uid}`;
  const existing = await batchGetDocuments(projectId, accessToken, [
    userPath,
    claimPath,
    legacyClaimPath,
    lookupPath,
  ]);
  const user = existing.get(userPath);
  const userData = user?.data || {};
  const currentMemberships = Array.isArray(userData.organizationMemberships)
    ? userData.organizationMemberships
    : [];

  const matchedClaim = existing.get(claimPath) || existing.get(legacyClaimPath);
  if (matchedClaim) {
    const organizationId = cleanString(matchedClaim.data.organizationId, "Organization registry entry");
    const organizationPath = `organizations/${organizationId}`;
    const memberPath = `${organizationPath}/members/${uid}`;
    const [organization, member] = await Promise.all([
      batchGetDocuments(projectId, accessToken, [organizationPath]),
      batchGetDocuments(projectId, accessToken, [memberPath]),
    ]).then(([organizations, members]) => [
      organizations.get(organizationPath),
      members.get(memberPath),
    ]);
    if (!organization) {
      throw apiError(500, "internal", "The organization registry needs administrator review.");
    }
    if (organization.data.verificationStatus === "rejected") {
      throw apiError(412, "failed-precondition", "This organization cannot accept new representative requests.");
    }
    if (member?.data.status === "rejected") {
      throw apiError(412, "failed-precondition", "This representative request was already rejected.");
    }

    const membershipStatus = member?.data.status || "pending";
    const summary = {
      organizationId,
      organizationName: organization.data.legalName || legalName,
      organizationStatus: organization.data.verificationStatus,
      role: member?.data.role || "representative",
      status: membershipStatus,
    };
    const hasOtherActiveOrganization =
      userData.organizationStatus === "verified" &&
      userData.organizationMembershipStatus === "approved" &&
      userData.organizationId !== organizationId;
    const userFields = {
      email,
      organizationMemberships: [
        ...currentMemberships.filter((item) => item.organizationId !== organizationId),
        summary,
      ],
    };
    if (!user) {
      Object.assign(userFields, {
        uid,
        name: action === "register" ? organization.data.legalName : contactPerson,
        role: action === "register" ? "organization" : "citizen",
        accountType: action === "register" ? "organization" : "citizen",
        nameDetails: action === "register"
          ? { organizationName: organization.data.legalName }
          : { firstName: contactPerson },
      });
    }
    if (!hasOtherActiveOrganization) {
      Object.assign(userFields, {
        organizationId,
        organizationStatus: organization.data.verificationStatus,
        organizationMembershipStatus: membershipStatus,
        activeOrganizationName: organization.data.legalName || legalName,
      });
    }
    if (action === "requestRepresentative") {
      userFields.organizationRequestStatus = membershipStatus === "approved" ? "approved" : "pending_review";
      userFields.organizationRequestName = organization.data.legalName || legalName;
    }
    if (action === "register") {
      Object.assign(userFields, {
        organizationDetails: { contactPerson, businessPermitNumber: permitNumber },
        organizationPermitUrl: permitDocumentUrl,
        phoneNumber: String(body.phoneNumber || "").trim(),
        addressDetails: address,
        isVerified: false,
      });
    }

    const writes = [];
    if (!member) {
      writes.push({
        path: memberPath,
        exists: false,
        fields: {
          uid,
          email,
          displayName: contactPerson,
          role: "representative",
          status: "pending",
        },
        transforms: ["createdAt", "updatedAt"],
      });
    }
    if (!existing.has(claimPath)) {
      writes.push({
        path: claimPath,
        exists: false,
        fields: { organizationId, aliasFromLegacyRegistry: true },
        transforms: ["createdAt"],
      });
    }
    writes.push({
      path: userPath,
      ...serverTimestampUpdate(userFields, user?.updateTime, Boolean(user)),
      transforms: [...(user ? ["updatedAt"] : ["createdAt", "updatedAt"])],
    });
    const pendingLookup = existing.get(lookupPath);
    if (action === "requestRepresentative" && pendingLookup?.data.status === "pending_lookup") {
      writes.push({
        path: lookupPath,
        updateTime: pendingLookup.updateTime,
        fields: { status: "linked", organizationId },
        transforms: ["linkedAt", "updatedAt"],
      });
    }
    await commitUpdates(projectId, accessToken, writes);
    return { status: membershipStatus === "approved" ? "approved" : "pending_review", organizationId };
  }

  const lookupRequest = existing.get(lookupPath);
  if (action === "requestRepresentative" && lookupRequest?.data.status === "pending_lookup") {
    return { status: "pending_review" };
  }

  if (action === "requestRepresentative") {
    const requestFields = {
      uid,
      email,
      legalName,
      normalizedName,
      permitIssuer,
      permitNumber,
      jurisdiction,
      permitFingerprint: permitFingerprints.exact,
      contactPerson,
      status: "pending_lookup",
    };
    const writes = [{
      path: lookupPath,
      ...serverTimestampUpdate(requestFields, lookupRequest?.updateTime, Boolean(lookupRequest)),
      transforms: [...(lookupRequest ? [] : ["createdAt"]), "updatedAt"],
    }];
    const userFields = { email, organizationRequestStatus: "pending_review", organizationRequestName: legalName };
    writes.push({
      path: userPath,
      ...serverTimestampUpdate(userFields, user?.updateTime, Boolean(user)),
    });
    await commitUpdates(projectId, accessToken, writes);
    return { status: "pending_review" };
  }

  if (
    user &&
    userData.organizationId &&
    ["pending", "verified"].includes(userData.organizationStatus)
  ) {
    throw apiError(412, "failed-precondition", "This account already has an organization application or membership.");
  }

  const nameMatches = await queryDocuments(projectId, accessToken, "organizations", "normalizedName", normalizedName, 1);
  const organizationId = crypto.randomUUID().replace(/-/g, "");
  const organizationPath = `organizations/${organizationId}`;
  const verificationPath = `${organizationPath}/private/verification`;
  const memberPath = `${organizationPath}/members/${uid}`;
  const summary = {
    organizationId,
    activeOrganizationName: legalName,
    organizationName: legalName,
    organizationStatus: "pending",
    role: "primary_representative",
    status: "pending",
  };
  const userFields = {
    uid,
    name: legalName,
    email,
    role: "organization",
    accountType: "organization",
    nameDetails: { organizationName: legalName },
    organizationDetails: { contactPerson, businessPermitNumber: permitNumber },
    organizationPermitUrl: permitDocumentUrl,
    organizationId,
    activeOrganizationName: legalName,
    organizationStatus: "pending",
    organizationMembershipStatus: "pending",
    organizationMemberships: [
      ...currentMemberships.filter((item) => item.organizationId !== organizationId),
      summary,
    ],
    phoneNumber: String(body.phoneNumber || "").trim(),
    addressDetails: address,
    isVerified: false,
  };
  const writes = [
    {
      path: organizationPath,
      exists: false,
      fields: {
        legalName,
        normalizedName,
        verificationStatus: "pending",
        reviewFlags: nameMatches.length ? ["possible_name_duplicate"] : [],
        primaryRepresentativeUid: uid,
        representativeCount: 1,
        createdBy: uid,
      },
      transforms: ["createdAt", "updatedAt"],
    },
    {
      path: verificationPath,
      exists: false,
      fields: {
        permitIssuer,
        permitNumber,
        jurisdiction,
        permitFingerprint: permitFingerprints.exact,
        permitDocumentUrl,
        submittedBy: uid,
      },
      transforms: ["submittedAt"],
    },
    {
      path: memberPath,
      exists: false,
      fields: {
        uid,
        email,
        displayName: contactPerson,
        role: "primary_representative",
        status: "pending",
      },
      transforms: ["createdAt", "updatedAt"],
    },
    {
      path: claimPath,
      exists: false,
      fields: { organizationId },
      transforms: ["createdAt"],
    },
    {
      path: userPath,
      ...serverTimestampUpdate(
        userFields,
        user?.updateTime,
        Boolean(user),
      ),
      transforms: [...(user ? [] : ["createdAt"]), "updatedAt"],
    },
  ];
  await commitUpdates(projectId, accessToken, writes);
  return { status: "pending_review", organizationId };
}

async function updateOrganizationPermit(body, applicant, env) {
  const organizationId = cleanString(body.organizationId, "Organization ID");
  const permitDocumentUrl = cloudinaryPermitUrl(body.permitDocumentUrl, env);
  const organizationPath = `organizations/${organizationId}`;
  const memberPath = `${organizationPath}/members/${applicant.uid}`;
  const verificationPath = `${organizationPath}/private/verification`;
  const userPath = `users/${applicant.uid}`;
  const records = await batchGetDocuments(applicant.projectId, applicant.accessToken, [
    organizationPath,
    memberPath,
    verificationPath,
    userPath,
  ]);
  const organization = records.get(organizationPath);
  const member = records.get(memberPath);
  const verification = records.get(verificationPath);
  const user = records.get(userPath);

  if (!organization) {
    throw apiError(404, "not-found", "Organization application not found.");
  }
  if (organization.data.primaryRepresentativeUid !== applicant.uid) {
    throw apiError(403, "permission-denied", "Only the primary representative can update this permit.");
  }
  if (organization.data.verificationStatus !== "pending") {
    throw apiError(412, "failed-precondition", "Only pending organization applications can update their permit.");
  }
  if (
    !member ||
    member.data.role !== "primary_representative" ||
    member.data.status !== "pending"
  ) {
    throw apiError(403, "permission-denied", "A pending primary representative membership is required.");
  }
  if (!verification || !user || user.data.organizationId !== organizationId) {
    throw apiError(412, "failed-precondition", "The organization application records are incomplete.");
  }

  await commitUpdates(applicant.projectId, applicant.accessToken, [
    {
      path: verificationPath,
      updateTime: verification.updateTime,
      fields: {
        permitDocumentUrl,
        permitUpdatedBy: applicant.uid,
      },
      transforms: ["permitUpdatedAt", "updatedAt"],
    },
    {
      path: userPath,
      updateTime: user.updateTime,
      fields: { organizationPermitUrl: permitDocumentUrl },
      transforms: ["updatedAt"],
    },
  ]);
  return { status: "pending_review" };
}

async function loadQueue(projectId, accessToken) {
  const [applications, pendingMembers, unmatchedRequests] = await Promise.all([
    queryDocuments(projectId, accessToken, "organizations", "verificationStatus", "pending", 50),
    queryDocuments(projectId, accessToken, "members", "status", "pending", 50, true),
    queryDocuments(projectId, accessToken, "organizationMembershipRequests", "status", "pending_lookup", 50),
  ]);

  const appPaths = applications.flatMap((application) => {
    const organizationId = application.path.split("/").at(-1);
    return [
      `organizations/${organizationId}/private/verification`,
      `users/${application.data.primaryRepresentativeUid || ""}`,
    ];
  });
  const memberDetails = pendingMembers.map((member) => {
    const parts = member.path.split("/");
    return { member, organizationId: parts[1], uid: member.data.uid || parts.at(-1) };
  });
  const detailPaths = [
    ...appPaths,
    ...memberDetails.map(({ organizationId, uid }) => `organizations/${organizationId}`),
    ...memberDetails.map(({ uid }) => `users/${uid}`),
  ];
  const details = await batchGetDocuments(projectId, accessToken, detailPaths);
  const authRecords = await lookupAuthUsers(
    projectId,
    accessToken,
    [
      ...applications.map((application) => application.data.primaryRepresentativeUid),
      ...memberDetails.map(({ uid }) => uid),
    ],
  );

  const organizationApplications = applications
    .sort((left, right) => String(right.createTime || "").localeCompare(String(left.createTime || "")))
    .map((application) => {
      const organizationId = application.path.split("/").at(-1);
      const representativeUid = application.data.primaryRepresentativeUid || "";
      const profile = details.get(`users/${representativeUid}`)?.data || {};
      const verification = details.get(`organizations/${organizationId}/private/verification`)?.data || {};
      const authRecord = authRecords.get(representativeUid) || {};
      return {
        organizationId,
        legalName: application.data.legalName || "",
        verificationStatus: application.data.verificationStatus,
        reviewFlags: Array.isArray(application.data.reviewFlags) ? application.data.reviewFlags : [],
        primaryRepresentativeUid: representativeUid,
        primaryRepresentativeName: profile.organizationDetails?.contactPerson || profile.contactPerson || "",
        primaryRepresentativeEmail: authRecord.email || profile.email || "",
        primaryRepresentativeEmailVerified: authRecord.emailVerified === true,
        permitIssuer: verification.permitIssuer || "",
        permitNumber: verification.permitNumber || "",
        jurisdiction: verification.jurisdiction || "",
        permitDocumentUrl: verification.permitDocumentUrl || "",
      };
    });

  const representativeRequests = memberDetails
    .filter(({ organizationId }) => details.get(`organizations/${organizationId}`)?.data?.verificationStatus === "verified")
    .map(({ member, organizationId, uid }) => {
      const organization = details.get(`organizations/${organizationId}`).data;
      const profile = details.get(`users/${uid}`)?.data || {};
      const authRecord = authRecords.get(uid) || {};
      return {
        organizationId,
        organizationName: organization.legalName || "",
        representativeUid: uid,
        representativeName: member.data.displayName || "",
        email: member.data.email || profile.email || authRecord.email || "",
        emailVerified: authRecord.emailVerified === true,
      };
    });

  return {
    applications: organizationApplications,
    representativeRequests,
    unmatchedRequests: unmatchedRequests.map((request) => ({
      requestId: request.path.split("/").at(-1),
      uid: request.data.uid || "",
      email: request.data.email || "",
      legalName: request.data.legalName || "",
      permitIssuer: request.data.permitIssuer || "",
      permitNumber: request.data.permitNumber || "",
      jurisdiction: request.data.jurisdiction || "",
      status: request.data.status || "pending_lookup",
    })),
  };
}

async function reviewRequest(body, reviewer, env) {
  const organizationId = cleanString(body.organizationId, "Organization ID");
  const decision = body.decision;
  if (!["verified", "rejected"].includes(decision)) {
    throw apiError(400, "invalid-argument", "Decision must be verified or rejected.");
  }
  const representativeUid = body.representativeUid
    ? cleanString(body.representativeUid, "Representative UID")
    : "";
  const organizationPath = `organizations/${organizationId}`;
  const initial = await batchGetDocuments(reviewer.projectId, reviewer.accessToken, [organizationPath]);
  const organizationDoc = initial.get(organizationPath);
  if (!organizationDoc) throw apiError(404, "not-found", "Organization application not found.");
  const organization = organizationDoc.data;

  if (representativeUid) {
    if (organization.verificationStatus !== "verified") {
      throw apiError(412, "failed-precondition", "Verify the organization before reviewing representatives.");
    }
    const memberPath = `${organizationPath}/members/${representativeUid}`;
    const userPath = `users/${representativeUid}`;
    const records = await batchGetDocuments(reviewer.projectId, reviewer.accessToken, [memberPath, userPath]);
    const member = records.get(memberPath);
    const user = records.get(userPath);
    if (!member || member.data.status !== "pending") {
      throw apiError(412, "failed-precondition", "No pending representative request was found.");
    }
    if (decision === "verified") {
      const authUsers = await lookupAuthUsers(reviewer.projectId, reviewer.accessToken, [representativeUid]);
      if (authUsers.get(representativeUid)?.emailVerified !== true) {
        throw apiError(412, "failed-precondition", "The representative must verify their sign-in email before approval.");
      }
    }

    const status = decision === "verified" ? "approved" : "rejected";
    const writes = [{
      path: memberPath,
      updateTime: member.updateTime,
      fields: { status, reviewedBy: reviewer.uid },
      transforms: ["reviewedAt", "updatedAt"],
    }];
    if (user) {
      const userData = user.data;
      const hasOtherApprovedOrganization = decision === "rejected" &&
        userData.organizationStatus === "verified" &&
        userData.organizationMembershipStatus === "approved" &&
        userData.organizationId !== organizationId;
      const fields = {
        organizationRequestStatus: status,
        organizationMemberships: membershipStatusList(userData, organizationId, "verified", status),
      };
      if (!hasOtherApprovedOrganization) {
        fields.organizationMembershipStatus = status;
        fields.organizationId = organizationId;
        fields.activeOrganizationName = organization.legalName || "";
        fields.organizationStatus = "verified";
      }
      writes.push({ path: userPath, updateTime: user.updateTime, fields, transforms: ["updatedAt"] });
    }
    await commitUpdates(reviewer.projectId, reviewer.accessToken, writes);
    return { status };
  }

  if (organization.verificationStatus !== "pending") {
    throw apiError(412, "failed-precondition", "This application has already been reviewed.");
  }
  const primaryUid = cleanString(organization.primaryRepresentativeUid, "Primary representative UID");
  const membershipPath = `${organizationPath}/members/${primaryUid}`;
  const verificationPath = `${organizationPath}/private/verification`;
  const userPath = `users/${primaryUid}`;
  const records = await batchGetDocuments(reviewer.projectId, reviewer.accessToken, [membershipPath, verificationPath, userPath]);
  const membership = records.get(membershipPath);
  const verification = records.get(verificationPath);
  const user = records.get(userPath);
  if (!membership || membership.data.status !== "pending") {
    throw apiError(412, "failed-precondition", "The primary representative request is not pending.");
  }
  if (!verification) {
    throw apiError(412, "failed-precondition", "The organization permit record is unavailable.");
  }
  if (decision === "verified") {
    cloudinaryPermitUrl(verification.data.permitDocumentUrl, env);
    const authUsers = await lookupAuthUsers(reviewer.projectId, reviewer.accessToken, [primaryUid]);
    if (authUsers.get(primaryUid)?.emailVerified !== true) {
      throw apiError(412, "failed-precondition", "The representative must verify their sign-in email before approval.");
    }
  }
  if (!user) throw apiError(412, "failed-precondition", "The primary representative profile is unavailable.");

  const status = decision === "verified" ? "verified" : "rejected";
  await commitUpdates(reviewer.projectId, reviewer.accessToken, [
    {
      path: organizationPath,
      updateTime: organizationDoc.updateTime,
      fields: { verificationStatus: status, reviewedBy: reviewer.uid },
      transforms: ["reviewedAt", "updatedAt"],
    },
    {
      path: membershipPath,
      updateTime: membership.updateTime,
      fields: { status: decision === "verified" ? "approved" : "rejected", reviewedBy: reviewer.uid },
      transforms: ["reviewedAt", "updatedAt"],
    },
    {
      path: userPath,
      updateTime: user.updateTime,
      fields: {
        organizationStatus: status,
        organizationMembershipStatus: decision === "verified" ? "approved" : "rejected",
        organizationMemberships: membershipStatusList(
          user.data,
          organizationId,
          status,
          decision === "verified" ? "approved" : "rejected",
        ),
      },
      transforms: ["updatedAt"],
    },
  ]);
  return { status };
}

async function rejectLookupRequest(body, reviewer) {
  const requestId = cleanString(body.requestId, "Request ID");
  const requestPath = `organizationMembershipRequests/${requestId}`;
  const requests = await batchGetDocuments(reviewer.projectId, reviewer.accessToken, [requestPath]);
  const request = requests.get(requestPath);
  if (!request || request.data.status !== "pending_lookup") {
    throw apiError(404, "not-found", "Pending organization lookup request not found.");
  }
  const uid = cleanString(request.data.uid, "Request user UID");
  const userPath = `users/${uid}`;
  const users = await batchGetDocuments(reviewer.projectId, reviewer.accessToken, [userPath]);
  const user = users.get(userPath);
  const writes = [{
    path: requestPath,
    updateTime: request.updateTime,
    fields: { status: "rejected", reviewedBy: reviewer.uid },
    transforms: ["reviewedAt", "updatedAt"],
  }];
  if (user) {
    writes.push({
      path: userPath,
      updateTime: user.updateTime,
      fields: { organizationRequestStatus: "rejected" },
      transforms: ["updatedAt"],
    });
  }
  await commitUpdates(reviewer.projectId, reviewer.accessToken, writes);
  return { status: "rejected" };
}

export function getAllowedOrigins(env) {
  return new Set(String(env.ADMIN_ORIGINS || "").split(",").map((origin) => origin.trim()).filter(Boolean));
}

export async function handleOrganizationAdminRequest(request, env) {
  const origin = request.headers.get("Origin") || "";
  const allowedOrigins = getAllowedOrigins(env);
  if (origin && !allowedOrigins.has(origin)) {
    return Response.json({ error: { code: "permission-denied", message: "This origin is not allowed." } }, { status: 403 });
  }
  const headers = {
    "Access-Control-Allow-Methods": "POST,OPTIONS",
    "Access-Control-Allow-Headers": "Authorization,Content-Type",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
    ...(origin ? { "Access-Control-Allow-Origin": origin } : {}),
  };
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (request.method !== "POST") {
    return Response.json({ error: { code: "method-not-allowed", message: "Use POST for organization review requests." } }, { status: 405, headers });
  }

  try {
    const contentLength = Number(request.headers.get("Content-Length") || 0);
    if (contentLength > 32_000) throw apiError(413, "resource-exhausted", "Request is too large.");
    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).length > 32_000) {
      throw apiError(413, "resource-exhausted", "Request is too large.");
    }
    let body;
    try {
      body = rawBody ? JSON.parse(rawBody) : {};
    } catch {
      throw apiError(400, "invalid-argument", "Request body must be valid JSON.");
    }
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw apiError(400, "invalid-argument", "Request body must be a JSON object.");
    }
    const path = new URL(request.url).pathname.replace(/\/$/, "");
    if (path === "/organization-admin/submit-application") {
      const applicant = await authenticateApplicant(request, env);
      const result = await submitOrganizationApplication(body, applicant, env);
      return Response.json(result, { status: 200, headers });
    }
    if (path === "/organization-admin/update-permit") {
      const applicant = await authenticateApplicant(request, env);
      const result = await updateOrganizationPermit(body, applicant, env);
      return Response.json(result, { status: 200, headers });
    }
    const reviewer = await authenticateReviewer(request, env);
    let result;
    if (path === "/organization-admin/list") {
      result = await loadQueue(reviewer.projectId, reviewer.accessToken);
    } else if (path === "/organization-admin/review") {
      result = await reviewRequest(body, reviewer, env);
    } else if (path === "/organization-admin/reject-lookup") {
      result = await rejectLookupRequest(body, reviewer);
    } else {
      throw apiError(404, "not-found", "Organization review endpoint not found.");
    }
    return Response.json(result, { status: 200, headers });
  } catch (error) {
    const status = Number(error?.status) || 500;
    const code = error?.code || "internal";
    const message = error instanceof OrganizationApiError
      ? error.message
      : "Organization review request failed. Check Worker logs for details.";
    console.error(JSON.stringify({
      event: "organization_admin_request_failed",
      path: new URL(request.url).pathname,
      code,
      message: error instanceof Error ? error.message : String(error),
    }));
    return Response.json({ error: { code, message } }, { status, headers });
  }
}
