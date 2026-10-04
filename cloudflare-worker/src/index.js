
import {
  handleOrganizationAdminRequest, verifyFirebaseIdToken,
  getGoogleAccessToken, commitUpdates,
} from './organizationAdmin.js';
import {
  MIN_PHOTO_CONFIDENCE, PhotoValidationError, parseOnSiteEvidence, plantNetFailure,
  receiptFields, validateEachPhoto, validatePhotoUrls,
} from '../../functions/tree_photo_validation.mjs';
import { classifyBark, fuseBarkSuggestions } from '../../functions/bark_species_classifier.mjs';

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
    species.scientificNameWithoutAuthor || species.scientificName || '';
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

async function downloadArrayBuffer(url) {
  // Workers supports manual redirects, not redirect: 'error'; reject 3xx below.
  const response = await fetch(url, { redirect: 'manual', signal: AbortSignal.timeout(15000) });
  if (!response.ok) {
    throw new PhotoValidationError(503, 'photo_unavailable', 'Could not read the uploaded photo. Replace it and retry.');
  }
  return await response.arrayBuffer();
}

function getPlantNetApiKey(env) {
  const apiKey = env.PLANTNET_API_KEY;
  if (!apiKey) {
    throw new PhotoValidationError(503, 'backend_not_ready',
      'Photo validation is not configured. Please contact support.');
  }
  return apiKey;
}

async function identifyWithPlantNetFetch({ imageBuffers, organs, env }) {
  const apiKey = getPlantNetApiKey(env);
  const project = env.PLANTNET_PROJECT || 'all';
  const endpoint = `https://my-api.plantnet.org/v2/identify/${project}?api-key=${encodeURIComponent(apiKey)}`;

  const formData = new FormData();
  imageBuffers.forEach((buffer, index) => {
    const organ = organs[index] || 'auto';
    formData.append('organs', organ);
    const blob = new Blob([buffer], { type: 'image/jpeg' });
    formData.append('images', blob, `image-${index}.jpg`);
  });

  const response = await fetch(endpoint, {
    method: 'POST',
    body: formData,
    signal: AbortSignal.timeout(30000),
  });

  if (!response.ok) {
    throw plantNetFailure(response.status);
  }

  return await response.json();
}

// Identifies a single photo via Pl@ntNet, then optionally fuses the result
// with a self-hosted bark/trunk classifier (see
// functions/bark_species_classifier.mjs and bark_classifier_service/).
// Fusion only runs for single-image calls — the client already analyzes one
// photo per request — and is a no-op whenever env.BARK_CLASSIFIER_URL is
// unset or the service is unavailable, so this always degrades gracefully
// to Pl@ntNet-only behavior.
//
// Pl@ntNet signals "no match" by throwing (not a 200 response), which is
// also the main failure mode for bark photos it can't recognize at all —
// so that specific, otherwise-safe-to-retry error is also eligible for
// rescue here. Any other error (outages, rate limits) still fails closed
// immediately, exactly as before this fusion existed.
async function identifySpeciesForImages({ imageBuffers, organs, env }) {
  const canUseBark = Boolean(env.BARK_CLASSIFIER_URL) && imageBuffers.length === 1;

  let suggestions = [];
  let bestMatchName = null;
  let plantNetError = null;
  try {
    const plantNetResponse = await identifyWithPlantNetFetch({ imageBuffers, organs, env });
    const rawResults = Array.isArray(plantNetResponse.results) ? plantNetResponse.results : [];
    suggestions = rawResults.slice(0, 5).map(normalizeSuggestion)
      .filter((item) => item.scientificName || item.commonNames.length > 0);
    bestMatchName = plantNetResponse.bestMatch || null;
  } catch (error) {
    if (!canUseBark || error?.code !== 'no_match') throw error;
    plantNetError = error;
  }

  if (canUseBark) {
    const predictions = await classifyBark({
      imageBuffer: imageBuffers[0],
      baseUrl: env.BARK_CLASSIFIER_URL,
      timeoutMs: Number(env.BARK_CLASSIFIER_TIMEOUT_MS) || 8000,
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

async function cloudinaryUploadPresetless({ env, folder, file }) {
  const cloudName = env.CLOUDINARY_CLOUD_NAME;
  const apiKey = env.CLOUDINARY_API_KEY;
  const apiSecret = env.CLOUDINARY_API_SECRET;

  if (!cloudName) throw new Error('CLOUDINARY_CLOUD_NAME is not configured.');
  if (!apiKey) throw new Error('CLOUDINARY_API_KEY is not configured.');
  if (!apiSecret) throw new Error('CLOUDINARY_API_SECRET is not configured.');

  const presetFolder = folder || env.CLOUDINARY_FOLDER || 'reports/evidence';
  const url = `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`;

  const form = new FormData();
  form.append('folder', presetFolder);
  form.append('resource_type', 'image');
  form.append('api_key', apiKey);
  form.append('file', file, 'upload.jpg');

  const response = await fetch(url, {
    method: 'POST',
    body: form,
  });

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`Cloudinary upload failed (${response.status}): ${text}`);
  }

  return await response.json();
}

function getCorsHeaders(request) {
  const origin = request.headers.get('Origin');
  return {
    'Access-Control-Allow-Origin': origin || '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization,Content-Type',
    'Access-Control-Max-Age': '86400',
  };
}

function withCorsResponse(response, request) {
  const cors = getCorsHeaders(request);
  const headers = new Headers(response.headers);
  for (const [k, v] of Object.entries(cors)) {
    headers.set(k, v);
  }
  return new Response(response.body, {
    status: response.status,
    headers,
  });
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    let validationStage = 'request';

    try {
      if (url.pathname.startsWith('/organization-admin/')) {
        return await handleOrganizationAdminRequest(request, env);
      }

      if (url.pathname === '/validateTreePhotos') {
        if (request.method === 'OPTIONS') {
          return new Response(null, { status: 204, headers: getCorsHeaders(request) });
        }
        if (request.method !== 'POST') {
          throw new PhotoValidationError(405, 'method_not_allowed', 'Use POST.');
        }
        validationStage = 'authentication';
        const uid = await verifyFirebaseIdToken(request, env);
        validationStage = 'input';
        const rawBody = await request.text();
        if (new TextEncoder().encode(rawBody).length > 32000) {
          throw new PhotoValidationError(413, 'invalid_photos', 'Too many photo attachments.');
        }
        let body;
        try { body = JSON.parse(rawBody); } catch {
          throw new PhotoValidationError(400, 'invalid_photos', 'Invalid photo request.');
        }
        const imageUrls = body.imageUrls;
        validatePhotoUrls(imageUrls, env.CLOUDINARY_CLOUD_NAME);
        const { captures, treeLocation } = parseOnSiteEvidence(body, imageUrls);
        validationStage = 'recognition';
        const result = await validateEachPhoto(imageUrls, async (imageUrl) => {
          const image = await downloadArrayBuffer(imageUrl);
          const { suggestions } = await identifySpeciesForImages({
            imageBuffers: [image], organs: ['auto'], env,
          });
          return suggestions;
        }, { onSite: captures, treeLocation });
        const validationId = crypto.randomUUID();
        const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
        validationStage = 'receipt';
        const token = await getGoogleAccessToken(env);
        await commitUpdates(env.FIREBASE_PROJECT_ID, token, [{
          path: `treePhotoValidations/${validationId}`,
          fields: receiptFields({ uid, imageUrls, expiresAt, result, treeLocation }),
        }]);
        if (result.unverifiedIndexes.length) {
          console.log(JSON.stringify({
            level: 'info', event: 'photo_species_unverified_onsite',
            photoIndexes: result.unverifiedIndexes,
          }));
        }
        return withCorsResponse(Response.json({
          validationId, evidencePhotoUrls: imageUrls, expiresAt: expiresAt.toISOString(),
          speciesVerification: result.speciesVerification,
          unverifiedPhotoIndexes: result.unverifiedIndexes,
        }), request);
      }

      if (request.method === 'POST' && url.pathname.endsWith('/uploadEvidence')) {
        const formData = await request.formData();
        const file = formData.get('file');

        if (!file) {
          return withCorsResponse(
            new Response(JSON.stringify({ error: 'Missing file field `file`' }), {
              status: 400,
              headers: { 'Content-Type': 'application/json' },
            }),
            request
          );
        }

        const folder = env.CLOUDINARY_FOLDER || 'reports/evidence';
        const result = await cloudinaryUploadPresetless({ env, folder, file });

        return withCorsResponse(
          new Response(
            JSON.stringify({ secure_url: result.secure_url, public_id: result.public_id }),
            {
              status: 200,
              headers: { 'Content-Type': 'application/json' },
            }
          ),
          request
        );
      }

      const identifyPathMatch =
        request.method === 'POST' || request.method === 'OPTIONS'
          ? url.pathname.endsWith('/identifySpecies') || url.pathname === '/'
          : url.pathname.endsWith('/identifySpecies');

      // CORS preflight
      if (request.method === 'OPTIONS' && (url.pathname.endsWith('/identifySpecies') || url.pathname === '/')) {
        return new Response(null, { status: 204, headers: getCorsHeaders(request) });
      }

      if (request.method === 'POST' && (url.pathname.endsWith('/identifySpecies') || url.pathname === '/')) {
        const body = await request.json();

        const imageUrls = Array.isArray(body?.imageUrls)
          ? body.imageUrls.filter((u) => typeof u === 'string' && u.trim())
          : [];

        if (imageUrls.length === 0) {
          return withCorsResponse(
            new Response(
              JSON.stringify({ error: 'Provide at least one imageUrls entry.' }),
              { status: 400, headers: { 'Content-Type': 'application/json' } }
            ),
            request
          );
        }

        if (imageUrls.length > 5) {
          return withCorsResponse(
            new Response(
              JSON.stringify({ error: 'A maximum of 5 images is supported.' }),
              { status: 400, headers: { 'Content-Type': 'application/json' } }
            ),
            request
          );
        }

        const organs = Array.isArray(body?.organs) ? body.organs : imageUrls.map(() => 'auto');

        const imageBuffers = await Promise.all(imageUrls.map((u) => downloadArrayBuffer(u.trim())));

        const { suggestions, bestMatchName } = await identifySpeciesForImages({
          imageBuffers,
          organs,
          env,
        });

        const bestMatch = suggestions.length > 0 ? suggestions[0] : null;

        return withCorsResponse(
          new Response(
            JSON.stringify({
              suggestions,
              bestMatch,
              evidencePhotoUrls: imageUrls,
              identifiedAt: new Date().toISOString(),
              bestMatchName,
            }),
            { status: 200, headers: { 'Content-Type': 'application/json' } }
          ),
          request
        );
      }

      return withCorsResponse(
        new Response(JSON.stringify({ error: 'Not found' }), {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        }),
        request
      );
    } catch (err) {
      // Do not return upstream payloads, internal configuration or credentials.
      console.error(JSON.stringify({
        event: 'photo_validation_failed',
        stage: validationStage,
        code: err?.code || err?.name || 'unknown',
        status: err?.status || err?.statusCode || 503,
        ...(Number.isInteger(err?.photoIndex) ? { photoIndex: err.photoIndex } : {}),
        ...(err instanceof PhotoValidationError && err.code === 'low_confidence'
          ? { confidence: err.confidence, requiredConfidence: MIN_PHOTO_CONFIDENCE } : {}),
      }));
      const storageFailure = url.pathname === '/validateTreePhotos' &&
        validationStage === 'receipt';
      const status = storageFailure ? 503 : err?.status || err?.statusCode || 503;
      const code = storageFailure ? 'validation_storage_unavailable'
        : err?.code || 'service_unavailable';
      return withCorsResponse(
        new Response(
          JSON.stringify({
            code,
            message: storageFailure
              ? 'The validation result could not be saved. Please contact support or retry later.'
              : code === 'unauthenticated' ? 'Sign in again to validate photos.'
              : err instanceof PhotoValidationError ? err.message
              : 'Photo analysis is unavailable. Please try again.',
            ...(Number.isInteger(err?.photoIndex) ? { photoIndex: err.photoIndex } : {}),
          }),
          { status, headers: { 'Content-Type': 'application/json' } }
        ),
        request
      );
    }
  },
};
