
import { handleOrganizationAdminRequest } from './organizationAdmin.js';

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
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to download image (${response.status}): ${url}`);
  }
  return await response.arrayBuffer();
}

function getPlantNetApiKey(env) {
  const apiKey = env.PLANTNET_API_KEY;
  if (!apiKey) throw new Error('PLANTNET_API_KEY is not configured.');
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
  });

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`PlantNet request failed (${response.status}): ${text}`);
  }

  return await response.json();
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

    try {
      if (url.pathname.startsWith('/organization-admin/')) {
        return await handleOrganizationAdminRequest(request, env);
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

        const plantNetResponse = await identifyWithPlantNetFetch({
          imageBuffers,
          organs,
          env,
        });

        const rawResults = Array.isArray(plantNetResponse.results) ? plantNetResponse.results : [];

        const suggestions = rawResults
          .slice(0, 5)
          .map(normalizeSuggestion)
          .filter((item) => item.scientificName || item.commonNames.length > 0);

        const bestMatch = suggestions.length > 0 ? suggestions[0] : null;

        return withCorsResponse(
          new Response(
            JSON.stringify({
              suggestions,
              bestMatch,
              evidencePhotoUrls: imageUrls,
              identifiedAt: new Date().toISOString(),
              bestMatchName: plantNetResponse.bestMatch || null,
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
      return withCorsResponse(
        new Response(
          JSON.stringify({
            error: 'Request failed',
            details: String(err?.message || err),
          }),
          { status: err?.statusCode || 500, headers: { 'Content-Type': 'application/json' } }
        ),
        request
      );
    }
  },
};

