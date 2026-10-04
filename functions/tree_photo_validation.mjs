export const MIN_PHOTO_CONFIDENCE = 0.5;

export class PhotoValidationError extends Error {
  constructor(status, code, message, photoIndex = null) {
    super(message);
    this.status = status;
    this.statusCode = status;
    this.code = code;
    this.photoIndex = photoIndex;
  }
}

export function plantNetFailure(status) {
  if (status === 404) {
    return new PhotoValidationError(422, 'no_match',
      'No plant could be recognized. Use a clear photo of the actual leaves or bark.');
  }
  if (status === 429) {
    return new PhotoValidationError(429, 'rate_limited',
      'Photo analysis is busy. Please try again later.');
  }
  return new PhotoValidationError(503, 'service_unavailable',
    'Photo analysis is temporarily unavailable. Keep your draft and try again.');
}

export function requireRecognizedPhoto(suggestions) {
  const best = suggestions[0];
  if (!best || typeof best.scientificName !== 'string' || !best.scientificName.trim()) {
    throw plantNetFailure(404);
  }
  if (!Number.isFinite(best.confidence) ||
      best.confidence < MIN_PHOTO_CONFIDENCE || best.confidence > 1) {
    const error = new PhotoValidationError(422, 'low_confidence',
      'We could not identify the plant confidently from this photo. Try a close-up of leaves or distinctive bark with minimal background. A clear photo can still be difficult to identify.');
    error.confidence = Number.isFinite(best.confidence) &&
      best.confidence >= 0 && best.confidence <= 1 ? best.confidence : null;
    throw error;
  }
}

export function validatePhotoUrls(imageUrls, cloudName) {
  if (!Array.isArray(imageUrls) || !imageUrls.length || !cloudName) {
    throw new PhotoValidationError(400, 'invalid_photos', 'Add photos of the trees before submitting.');
  }
  for (const value of imageUrls) {
    let url;
    try { url = new URL(value); } catch {
      throw new PhotoValidationError(400, 'invalid_photos', 'Replace the invalid photo attachment.');
    }
    // Only immutable versioned uploads in this application's cloud may be fetched.
    const prefix = `/${cloudName}/image/upload/`;
    if (typeof value !== 'string' || url.protocol !== 'https:' ||
        url.hostname !== 'res.cloudinary.com' || url.port || url.username ||
        url.password || url.search || url.hash ||
        !url.pathname.startsWith(prefix) ||
        !/^v\d+\/[^?]+$/.test(url.pathname.slice(prefix.length))) {
      throw new PhotoValidationError(400, 'invalid_photos', 'Replace the invalid photo attachment.');
    }
  }
}

// On-site fallback for trees whose species cannot be recognized (e.g. leafless
// or dead trees). Location values are reported by the client and cannot be
// proven server-side; they raise the effort of reusing unrelated photos, and
// every such application is flagged for mandatory field inspection.
export const ON_SITE_MAX_ACCURACY_METERS = 50;
export const ON_SITE_MAX_DISTANCE_METERS = 100;
export const ON_SITE_MAX_AGE_MS = 24 * 60 * 60 * 1000;
const ON_SITE_CLOCK_SKEW_MS = 5 * 60 * 1000;
export const SPECIES_VERIFIED = 'verified';
export const SPECIES_UNVERIFIED_ON_SITE = 'unverified_onsite';
const RECOGNITION_UNCERTAIN = new Set(['no_match', 'low_confidence']);

function invalidEvidence() {
  return new PhotoValidationError(400, 'invalid_photos', 'Invalid on-site photo details.');
}

function coordinate(value, limit) {
  return typeof value === 'number' && Number.isFinite(value) && Math.abs(value) <= limit;
}

export function parseOnSiteEvidence(body, imageUrls) {
  const raw = body?.onSiteCaptures;
  if (raw === undefined || raw === null) return { captures: new Map(), treeLocation: null };
  if (!Array.isArray(raw) || raw.length > imageUrls.length) throw invalidEvidence();
  const location = body?.treeLocation;
  if (!location || !coordinate(location.latitude, 90) || !coordinate(location.longitude, 180)) {
    throw invalidEvidence();
  }
  const captures = new Map();
  for (const capture of raw) {
    const capturedAt = Date.parse(capture?.capturedAt);
    if (!imageUrls.includes(capture?.url) || captures.has(capture.url) ||
        !coordinate(capture.latitude, 90) || !coordinate(capture.longitude, 180) ||
        typeof capture.accuracyMeters !== 'number' ||
        !Number.isFinite(capture.accuracyMeters) || capture.accuracyMeters < 0 ||
        !Number.isFinite(capturedAt)) {
      throw invalidEvidence();
    }
    captures.set(capture.url, {
      latitude: capture.latitude, longitude: capture.longitude,
      accuracyMeters: capture.accuracyMeters, capturedAt,
    });
  }
  return {
    captures,
    treeLocation: captures.size
      ? { latitude: location.latitude, longitude: location.longitude } : null,
  };
}

export function distanceMeters(a, b) {
  const radians = (degrees) => degrees * Math.PI / 180;
  const dLat = radians(b.latitude - a.latitude);
  const dLng = radians(b.longitude - a.longitude);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(radians(a.latitude)) *
    Math.cos(radians(b.latitude)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function requireOnSiteCapture(capture, treeLocation, now = Date.now()) {
  if (capture.accuracyMeters > ON_SITE_MAX_ACCURACY_METERS ||
      capture.capturedAt > now + ON_SITE_CLOCK_SKEW_MS ||
      now - capture.capturedAt > ON_SITE_MAX_AGE_MS) {
    throw new PhotoValidationError(422, 'onsite_gps_unreliable',
      'The species could not be confirmed, and this photo has no accurate, recent location. Retake it with location on while standing at the tree.');
  }
  if (distanceMeters(capture, treeLocation) > ON_SITE_MAX_DISTANCE_METERS) {
    throw new PhotoValidationError(422, 'onsite_too_far',
      'The species could not be confirmed, and this photo was taken too far from the pinned tree location. Retake it at the tree or correct the pin.');
  }
}

/**
 * Every photo must be recognized, or — only when recognition is uncertain —
 * carry valid on-site capture evidence. Outages never fall back.
 */
export async function validateEachPhoto(imageUrls, identify, {
  onSite = new Map(), treeLocation = null, now = Date.now(),
} = {}) {
  const unverifiedIndexes = [];
  for (let index = 0; index < imageUrls.length; index++) {
    try {
      try {
        const suggestions = await identify(imageUrls[index]);
        requireRecognizedPhoto(suggestions);
      } catch (error) {
        const capture = onSite.get(imageUrls[index]);
        if (!(error instanceof PhotoValidationError) ||
            !RECOGNITION_UNCERTAIN.has(error.code) || !capture || !treeLocation) {
          throw error;
        }
        requireOnSiteCapture(capture, treeLocation, now);
        unverifiedIndexes.push(index);
      }
    } catch (error) {
      if (error instanceof PhotoValidationError) error.photoIndex = index;
      throw error;
    }
  }
  return {
    unverifiedIndexes,
    speciesVerification: unverifiedIndexes.length
      ? SPECIES_UNVERIFIED_ON_SITE : SPECIES_VERIFIED,
  };
}

export function receiptFields({ uid, imageUrls, expiresAt, result, treeLocation }) {
  return {
    uid, imageUrls, accepted: true, expiresAt,
    speciesVerification: result.speciesVerification,
    ...(result.unverifiedIndexes.length ? {
      unverifiedPhotoUrls: result.unverifiedIndexes.map((index) => imageUrls[index]),
      treeLatitude: treeLocation.latitude,
      treeLongitude: treeLocation.longitude,
    } : {}),
  };
}
