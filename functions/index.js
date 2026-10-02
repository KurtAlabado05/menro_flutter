// Firebase Cloud Functions for EcoMap:
// - uploadEvidence: Cloudinary evidence uploads
// - identifySpecies: Pl@ntNet tree species identification proxy

const functions = require('firebase-functions');
const express = require('express');
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const axios = require('axios');
const FormData = require('form-data');
const admin = require('firebase-admin');
const {
  OrganizationRegistrationError,
  createOrganizationHandlers,
} = require('./organization_registration');

if (!admin.apps.length) {
  admin.initializeApp();
}

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const DROPDOWN_ALIASES = {
  Mahogany: ['swietenia macrophylla', 'mahogany', 'big-leaf mahogany'],
  'Mango (Mangifera indica)': ['mangifera indica', 'mango', 'mangga'],
  Gmelina: ['gmelina arborea', 'gmelina', 'yemane'],
  Acacia: ['acacia mangium', 'acacia auriculiformis', 'acacia'],
  Narra: ['pterocarpus indicus', 'narra', 'amboyna'],
  'Ipil-Ipil': ['leucaena leucocephala', 'ipil-ipil', 'ipil ipil', 'lead tree'],
  Coconut: ['cocos nucifera', 'coconut', 'niyog', 'coco palm'],
};

const OTHERS_LABEL = 'Others (Specify Variant Name)';

function matchDropdownLabel(scientificName, commonNames = []) {
  const haystack = new Set(
    [scientificName, ...commonNames]
      .filter(Boolean)
      .map((value) => value.toLowerCase().trim())
  );

  for (const [label, aliases] of Object.entries(DROPDOWN_ALIASES)) {
    for (const alias of aliases) {
      for (const value of haystack) {
        if (value.includes(alias) || alias.includes(value)) {
          return label;
        }
      }
    }
  }

  return OTHERS_LABEL;
}

function normalizeSuggestion(resultItem) {
  const species = resultItem.species || {};
  const scientificName =
    species.scientificNameWithoutAuthor ||
    species.scientificName ||
    '';
  const commonNames = Array.isArray(species.commonNames)
    ? species.commonNames.filter(Boolean)
    : [];

  return {
    scientificName,
    commonNames,
    confidence: typeof resultItem.score === 'number' ? resultItem.score : 0,
    matchedDropdownLabel: matchDropdownLabel(scientificName, commonNames),
  };
}

async function downloadImageBuffer(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to download image (${response.status}): ${url}`);
  }
  const arrayBuffer = await response.arrayBuffer();
  return Buffer.from(arrayBuffer);
}

async function identifyWithPlantNet({ imageBuffers, organs }) {
  const apiKey = process.env.PLANTNET_API_KEY;
  if (!apiKey) {
    throw new Error('PLANTNET_API_KEY is not configured.');
  }

  const project = process.env.PLANTNET_PROJECT || 'all';
  const endpoint = `https://my-api.plantnet.org/v2/identify/${project}?api-key=${apiKey}`;

  const formData = new FormData();
  imageBuffers.forEach((buffer, index) => {
    const organ = organs[index] || 'auto';
    formData.append('organs', organ);
    formData.append('images', buffer, {
      filename: `image-${index}.jpg`,
      contentType: 'image/jpeg',
    });
  });

  const response = await axios.post(endpoint, formData, {
    headers: formData.getHeaders(),
    maxBodyLength: Infinity,
  });

  return response.data;
}

async function verifyAuth(req) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice(7)
    : null;

  if (!token) {
    const error = new Error('Missing Authorization bearer token.');
    error.statusCode = 401;
    throw error;
  }

  return admin.auth().verifyIdToken(token);
}

// ─── uploadEvidence ───────────────────────────────────────────────────────────

const uploadApp = express();

uploadApp.post('/uploadEvidence', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Missing file field `file`' });
    }

    const folder = process.env.CLOUDINARY_FOLDER || 'reports/evidence';

    const result = await new Promise((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        {
          folder,
          resource_type: 'image',
        },
        (error, uploadResult) => {
          if (error) return reject(error);
          return resolve(uploadResult);
        }
      );

      uploadStream.end(req.file.buffer);
    });

    return res.json({
      secure_url: result.secure_url,
      public_id: result.public_id,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({
      error: 'Cloudinary upload failed',
      details: String(err),
    });
  }
});

exports.uploadEvidence = functions.https.onRequest(uploadApp);

const organizationHandlers = createOrganizationHandlers({
  db: admin.firestore(),
  auth: admin.auth(),
  fieldValue: admin.firestore.FieldValue,
  secret: process.env.ORG_REGISTRY_HMAC_KEY,
});

exports.submitOrganizationApplication = functions
  .runWith({ secrets: ['ORG_REGISTRY_HMAC_KEY'] })
  .https.onCall(async (data, context) => {
    try {
      return await organizationHandlers.submitApplication(data, context);
    } catch (error) {
      if (error instanceof OrganizationRegistrationError) {
        throw new functions.https.HttpsError(error.code, error.message);
      }
      console.error('submitOrganizationApplication failed:', error);
      throw new functions.https.HttpsError('internal', 'Unable to submit the organization request.');
    }
  });

exports.reviewOrganizationApplication = functions
  .https.onCall(async (data, context) => {
    try {
      return await organizationHandlers.reviewApplication(data, context);
    } catch (error) {
      if (error instanceof OrganizationRegistrationError) {
        throw new functions.https.HttpsError(error.code, error.message);
      }
      console.error('reviewOrganizationApplication failed:', error);
      throw new functions.https.HttpsError('internal', 'Unable to review the organization application.');
    }
  });

exports.updateOrganizationPermitDocument = functions
  .https.onCall(async (data, context) => {
    try {
      return await organizationHandlers.updateOrganizationPermit(data, context);
    } catch (error) {
      if (error instanceof OrganizationRegistrationError) {
        throw new functions.https.HttpsError(error.code, error.message);
      }
      console.error('updateOrganizationPermitDocument failed:', error);
      throw new functions.https.HttpsError('internal', 'Unable to update the organization permit.');
    }
  });

exports.listPendingOrganizationApplications = functions
  .https.onCall(async (_data, context) => {
    try {
      return await organizationHandlers.listPendingApplications(context);
    } catch (error) {
      if (error instanceof OrganizationRegistrationError) {
        throw new functions.https.HttpsError(error.code, error.message);
      }
      console.error('listPendingOrganizationApplications failed:', error);
      throw new functions.https.HttpsError('internal', 'Unable to load organization applications.');
    }
  });

exports.rejectOrganizationLookupRequest = functions
  .https.onCall(async (data, context) => {
    try {
      return await organizationHandlers.rejectLookupRequest(data, context);
    } catch (error) {
      if (error instanceof OrganizationRegistrationError) {
        throw new functions.https.HttpsError(error.code, error.message);
      }
      console.error('rejectOrganizationLookupRequest failed:', error);
      throw new functions.https.HttpsError('internal', 'Unable to review the representative request.');
    }
  });

// Archive reports after their 48-hour active window so they no longer block
// new submissions or appear in the public report feed.
exports.archiveExpiredReports = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await admin
      .firestore()
      .collection('reports')
      .where('expiresAt', '<=', now)
      .get();

    if (snapshot.empty) return null;
    const batch = admin.firestore().batch();
    snapshot.docs.forEach((doc) => {
      const status = String(doc.data().status || '').toLowerCase().trim();
      if (!['resolved', 'completed', 'closed', 'archived'].includes(status)) {
        batch.update(doc.ref, {
          status: 'archived',
          archivedAt: now,
          archiveReason: 'Automatically archived after 48 hours',
        });
      }
    });
    await batch.commit();
    return null;
  });

// ─── identifySpecies ──────────────────────────────────────────────────────────

const identifyApp = express();
identifyApp.use(express.json({ limit: '1mb' }));

identifyApp.post('/', async (req, res) => {
  try {
    await verifyAuth(req);

    const imageUrls = Array.isArray(req.body?.imageUrls)
      ? req.body.imageUrls.filter((url) => typeof url === 'string' && url.trim())
      : [];

    if (imageUrls.length === 0) {
      return res.status(400).json({ error: 'Provide at least one imageUrls entry.' });
    }

    if (imageUrls.length > 5) {
      return res.status(400).json({ error: 'A maximum of 5 images is supported.' });
    }

    const organs = Array.isArray(req.body?.organs)
      ? req.body.organs
      : imageUrls.map(() => 'auto');

    const imageBuffers = await Promise.all(
      imageUrls.map((url) => downloadImageBuffer(url.trim()))
    );

    const plantNetResponse = await identifyWithPlantNet({
      imageBuffers,
      organs,
    });

    const rawResults = Array.isArray(plantNetResponse.results)
      ? plantNetResponse.results
      : [];

    const suggestions = rawResults
      .slice(0, 5)
      .map(normalizeSuggestion)
      .filter((item) => item.scientificName || item.commonNames.length > 0);

    const bestMatch = suggestions.length > 0 ? suggestions[0] : null;

    return res.json({
      suggestions,
      bestMatch,
      evidencePhotoUrls: imageUrls,
      identifiedAt: new Date().toISOString(),
      bestMatchName: plantNetResponse.bestMatch || null,
    });
  } catch (err) {
    console.error('identifySpecies error:', err);
    const statusCode = err.statusCode || 500;
    return res.status(statusCode).json({
      error: 'Species identification failed',
      details: String(err.message || err),
    });
  }
});

exports.identifySpecies = functions.https.onRequest(identifyApp);
