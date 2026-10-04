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
  'White Lauan': ['shorea contorta', 'pentacme contorta', 'white lauan', 'white lauaan'],
  Guijo: ['shorea guiso', 'guijo', 'red balau', 'red balan'],
  Apitong: ['dipterocarpus grandiflorus', 'apitong', 'apiton'],
  'Red Lauan': ['shorea negrosensis', 'rubroshorea negrosensis', 'red lauan'],
  // "Mayapis" is applied regionally to two different Dipterocarpaceae genera
  // in the field (Shorea palosapis and Anisoptera thurifera); both
  // scientific-name aliases are listed so either resolves to this label.
  Mayapis: ['shorea palosapis', 'rubroshorea palosapis', 'anisoptera thurifera', 'mayapis', 'palosapis'],
  Tindalo: ['afzelia rhomboidea', 'pahudia rhomboidea', 'intsia rhomboidea', 'tindalo'],
  Bolongeta: ['diospyros pilosanthera', 'bolongeta', 'bolong-eta'],
  // Sources disagree on whether "Malaikmo" refers to Celtis philippensis or
  // the congener Celtis luzonica; both are listed as aliases.
  Malaikmo: ['celtis philippensis', 'celtis luzonica', 'malaikmo', 'malaitmo'],
  Bayanti: ['aglaia rimosa', 'bayanti', 'bayati'],
  Malatanglin: ['adenanthera pavonina', 'malatanglin'],
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

// Used only to give a confident bark-only suggestion (see
// identifySpeciesForImages/fuseBarkSuggestions) a real scientific name: the
// first alias per dropdown label is always its canonical binomial name.
function scientificNameForDropdownLabel(label) {
  const [binomial] = DROPDOWN_ALIASES[label] || [];
  if (!binomial) return '';
  return binomial.charAt(0).toUpperCase() + binomial.slice(1);
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
  const response = await fetch(url, { redirect: 'error', signal: AbortSignal.timeout(15000) });
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
    timeout: 30000,
    validateStatus: () => true,
  });

  if (response.status < 200 || response.status >= 300) {
    const { plantNetFailure } = await import('./tree_photo_validation.mjs');
    throw plantNetFailure(response.status);
  }
  return response.data;
}

// Identifies a single photo via Pl@ntNet, then optionally fuses the result
// with a self-hosted bark/trunk classifier (see bark_species_classifier.mjs
// and bark_classifier_service/). Fusion only runs for single-image calls —
// the client already analyzes one photo per request — and is a no-op
// whenever BARK_CLASSIFIER_URL is unset or the service is unavailable, so
// this always degrades gracefully to today's Pl@ntNet-only behavior.
//
// Pl@ntNet signals "no match" by throwing (not a 200 response), which is
// also the main failure mode for bark photos it can't recognize at all —
// so that specific, otherwise-safe-to-retry error is also eligible for
// rescue here. Any other error (outages, rate limits) still fails closed
// immediately, exactly as before this fusion existed.
async function identifySpeciesForImages({ imageBuffers, organs }) {
  const barkClassifierUrl = process.env.BARK_CLASSIFIER_URL;
  const canUseBark = Boolean(barkClassifierUrl) && imageBuffers.length === 1;

  let suggestions = [];
  let bestMatchName = null;
  let plantNetError = null;
  try {
    const plantNetResponse = await identifyWithPlantNet({ imageBuffers, organs });
    const rawResults = Array.isArray(plantNetResponse.results) ? plantNetResponse.results : [];
    suggestions = rawResults.slice(0, 5).map(normalizeSuggestion)
      .filter((item) => item.scientificName || item.commonNames.length > 0);
    bestMatchName = plantNetResponse.bestMatch || null;
  } catch (error) {
    if (!canUseBark || error?.code !== 'no_match') throw error;
    plantNetError = error;
  }

  if (canUseBark) {
    const { classifyBark, fuseBarkSuggestions } = await import('./bark_species_classifier.mjs');
    const predictions = await classifyBark({
      imageBuffer: imageBuffers[0],
      baseUrl: barkClassifierUrl,
      timeoutMs: Number(process.env.BARK_CLASSIFIER_TIMEOUT_MS) || 8000,
    });
    const fused = fuseBarkSuggestions(suggestions, predictions, {
      matchDropdownLabel,
      scientificNameForLabel: scientificNameForDropdownLabel,
    });
    // Pl@ntNet found nothing and the bark classifier couldn't rescue it
    // either: preserve the original no_match error exactly as before,
    // rather than silently returning an empty "success".
    if (plantNetError && fused.length === 0) throw plantNetError;
    suggestions = fused;
  }

  return { suggestions, bestMatchName };
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

    const { suggestions, bestMatchName } = await identifySpeciesForImages({
      imageBuffers,
      organs,
    });

    const bestMatch = suggestions.length > 0 ? suggestions[0] : null;

    return res.json({
      suggestions,
      bestMatch,
      evidencePhotoUrls: imageUrls,
      identifiedAt: new Date().toISOString(),
      bestMatchName,
    });
  } catch (err) {
    console.error('identifySpecies error:', err.code || err.name);
    const statusCode = err.statusCode || 500;
    return res.status(statusCode).json({
      code: err.code || 'service_unavailable',
      message: err.statusCode === 422 ? err.message : 'Photo analysis is unavailable. Please try again.',
    });
  }
});

exports.identifySpecies = functions.https.onRequest(identifyApp);

const validatePhotosApp = express();
validatePhotosApp.use((req, res, next) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Authorization,Content-Type');
  res.set('Access-Control-Allow-Methods', 'POST,OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();
  return next();
});
validatePhotosApp.use(express.json({ limit: '32kb' }));
validatePhotosApp.post('/', async (req, res) => {
  try {
    const decoded = await verifyAuth(req);
    const {
      parseOnSiteEvidence, receiptFields, validateEachPhoto, validatePhotoUrls,
    } = await import('./tree_photo_validation.mjs');
    const imageUrls = req.body?.imageUrls;
    validatePhotoUrls(imageUrls, process.env.CLOUDINARY_CLOUD_NAME);
    const { captures, treeLocation } = parseOnSiteEvidence(req.body, imageUrls);
    const result = await validateEachPhoto(imageUrls, async (url) => {
      const buffer = await downloadImageBuffer(url);
      const { suggestions } = await identifySpeciesForImages({
        imageBuffers: [buffer], organs: ['auto'],
      });
      return suggestions;
    }, { onSite: captures, treeLocation });
    const receipt = admin.firestore().collection('treePhotoValidations').doc();
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    await receipt.set(receiptFields({
      uid: decoded.uid, imageUrls, expiresAt, result, treeLocation,
    }));
    return res.json({
      validationId: receipt.id, evidencePhotoUrls: imageUrls,
      expiresAt: expiresAt.toISOString(),
      speciesVerification: result.speciesVerification,
      unverifiedPhotoIndexes: result.unverifiedIndexes,
    });
  } catch (err) {
    console.error('validateTreePhotos failed:', err.code || err.name);
    return res.status(err.statusCode || 503).json({
      code: err.code || 'service_unavailable',
      message: err.statusCode === 422 ? err.message : 'Photo validation is unavailable. Please try again.',
      ...(Number.isInteger(err.photoIndex) ? { photoIndex: err.photoIndex } : {}),
    });
  }
});
exports.validateTreePhotos = functions.https.onRequest(validatePhotosApp);
