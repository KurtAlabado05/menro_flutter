// Optional fusion with a self-hosted bark/trunk species classifier.
//
// Pl@ntNet's accuracy is markedly weaker on bark/trunk photos than on leaf
// photos (bark is a texture-classification problem, not the flower/leaf
// shape matching Pl@ntNet's models are strongest at). This module lets the
// backend call an optional, self-hosted classifier trained only on this
// application's known permit species (see functions/README.md and
// bark_classifier_service/ for how to train and deploy one) and fuse its
// prediction with Pl@ntNet's.
//
// Design goals:
// - Zero behavior change when BARK_CLASSIFIER_URL is not configured, or the
//   service is unreachable/slow: every call degrades gracefully to
//   Pl@ntNet-only results.
// - Pl@ntNet stays authoritative. The bark classifier can only raise
//   confidence for a species Pl@ntNet already proposed (agreement), or
//   produce a capped, clearly-flagged suggestion of its own when Pl@ntNet
//   found nothing at all. It can never outrank or override a confident,
//   disagreeing Pl@ntNet result.

export const DEFAULT_BARK_TRUST_THRESHOLD = 0.6;
export const DEFAULT_AGREEMENT_CONFIDENCE_CAP = 0.9;
export const DEFAULT_SOLO_CONFIDENCE_CAP = 0.7;

/**
 * Calls the self-hosted bark classifier's `/predict` endpoint with a single
 * image. Returns a confidence-sorted array of `{ label, confidence }`
 * predictions (label values are permit dropdown labels, e.g. "Narra"), or
 * `null` if the service is not configured, unreachable, slow, or returns a
 * malformed response. Callers must treat `null` as "no opinion" and must not
 * surface classifier outages to the user.
 */
export async function classifyBark({
  imageBuffer,
  baseUrl,
  timeoutMs = 8000,
  fetchImpl = fetch,
}) {
  if (!baseUrl || !imageBuffer) return null;
  try {
    const form = new FormData();
    form.append('image', new Blob([imageBuffer]), 'bark.jpg');
    const response = await fetchImpl(`${baseUrl.replace(/\/+$/, '')}/predict`, {
      method: 'POST',
      body: form,
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!response.ok) return null;
    const data = await response.json();
    if (!Array.isArray(data?.predictions)) return null;
    const predictions = data.predictions.filter(
      (p) => p && typeof p.label === 'string' && p.label.trim() &&
        Number.isFinite(p.confidence) && p.confidence >= 0 && p.confidence <= 1
    );
    return predictions.sort((a, b) => b.confidence - a.confidence);
  } catch {
    // Network error, timeout, or malformed JSON: treat as "no opinion".
    return null;
  }
}

/**
 * Fuses Pl@ntNet `suggestions` (already normalized, confidence-sorted, each
 * with a `matchedDropdownLabel`) with the bark classifier's `predictions`
 * (as returned by `classifyBark`, or `null`). Returns a possibly-updated,
 * confidence-sorted suggestions array; never mutates its inputs.
 */
export function fuseBarkSuggestions(suggestions, predictions, {
  matchDropdownLabel,
  scientificNameForLabel,
  barkTrustThreshold = DEFAULT_BARK_TRUST_THRESHOLD,
  agreementConfidenceCap = DEFAULT_AGREEMENT_CONFIDENCE_CAP,
  soloConfidenceCap = DEFAULT_SOLO_CONFIDENCE_CAP,
} = {}) {
  const base = Array.isArray(suggestions) ? suggestions : [];
  const topBark = Array.isArray(predictions) && predictions.length ? predictions[0] : null;
  if (!topBark || typeof matchDropdownLabel !== 'function' ||
      !(topBark.confidence >= barkTrustThreshold)) {
    return base;
  }

  const matchIndex = base.findIndex((s) => s.matchedDropdownLabel === topBark.label);
  if (matchIndex !== -1) {
    const matched = base[matchIndex];
    const fusedConfidence = Math.min(
      agreementConfidenceCap,
      Math.max(matched.confidence, topBark.confidence)
    );
    if (fusedConfidence <= matched.confidence) return base;
    const next = [...base];
    next[matchIndex] = {
      ...matched,
      confidence: fusedConfidence,
      barkFusion: { agreed: true, barkConfidence: topBark.confidence },
    };
    next.sort((a, b) => b.confidence - a.confidence);
    return next;
  }

  // Pl@ntNet found nothing at all: offer a capped, clearly-flagged
  // bark-only suggestion rather than leaving the photo unrecognized.
  // Never synthesize a competing entry when Pl@ntNet already proposed a
  // *different* species — that would second-guess a real Pl@ntNet result.
  // A non-empty scientificName is required: both this backend's own
  // recognition gate (requireRecognizedPhoto) and the Flutter client reject
  // any top suggestion with a blank scientificName as "no match".
  if (base.length === 0) {
    const scientificName = typeof scientificNameForLabel === 'function'
      ? (scientificNameForLabel(topBark.label) || '').trim()
      : '';
    if (!scientificName) return base;
    return [{
      scientificName,
      commonNames: [],
      confidence: Math.min(soloConfidenceCap, topBark.confidence),
      matchedDropdownLabel: topBark.label,
      barkFusion: { agreed: false, barkConfidence: topBark.confidence, soloSource: true },
    }];
  }

  return base;
}
