import test from 'node:test';
import assert from 'node:assert/strict';
import {
  classifyBark, fuseBarkSuggestions,
  DEFAULT_BARK_TRUST_THRESHOLD, DEFAULT_AGREEMENT_CONFIDENCE_CAP, DEFAULT_SOLO_CONFIDENCE_CAP,
} from './bark_species_classifier.mjs';

function matchDropdownLabel(name) {
  return name === 'Narra' ? 'Narra' : 'Others (Specify Variant Name)';
}

test('classifyBark returns null when not configured, unreachable, or malformed', async () => {
  assert.equal(await classifyBark({ imageBuffer: Buffer.from('x'), baseUrl: '' }), null);
  assert.equal(await classifyBark({ imageBuffer: null, baseUrl: 'https://bark.example' }), null);
  assert.equal(await classifyBark({
    imageBuffer: Buffer.from('x'), baseUrl: 'https://bark.example',
    fetchImpl: async () => { throw new Error('offline'); },
  }), null);
  assert.equal(await classifyBark({
    imageBuffer: Buffer.from('x'), baseUrl: 'https://bark.example',
    fetchImpl: async () => ({ ok: false }),
  }), null);
  assert.equal(await classifyBark({
    imageBuffer: Buffer.from('x'), baseUrl: 'https://bark.example',
    fetchImpl: async () => ({ ok: true, json: async () => ({ predictions: 'not-an-array' }) }),
  }), null);
});

test('classifyBark sorts predictions by confidence and drops invalid entries', async () => {
  const predictions = await classifyBark({
    imageBuffer: Buffer.from('x'), baseUrl: 'https://bark.example/',
    fetchImpl: async (url, init) => {
      assert.equal(url, 'https://bark.example/predict');
      assert.equal(init.method, 'POST');
      return {
        ok: true,
        json: async () => ({
          predictions: [
            { label: 'Narra', confidence: 0.4 },
            { label: 'Acacia', confidence: 0.9 },
            { label: '', confidence: 0.99 },
            { label: 'Mango (Mangifera indica)', confidence: NaN },
            { label: 'Coconut', confidence: 1.5 },
          ],
        }),
      };
    },
  });
  assert.deepEqual(predictions, [
    { label: 'Acacia', confidence: 0.9 },
    { label: 'Narra', confidence: 0.4 },
  ]);
});

test('fusion is a no-op without a confident top bark prediction', () => {
  const suggestions = [{ scientificName: 'Pterocarpus indicus', confidence: 0.3, matchedDropdownLabel: 'Narra' }];
  assert.equal(fuseBarkSuggestions(suggestions, null, { matchDropdownLabel }), suggestions);
  assert.equal(fuseBarkSuggestions(suggestions, [], { matchDropdownLabel }), suggestions);
  assert.equal(
    fuseBarkSuggestions(suggestions, [{ label: 'Narra', confidence: DEFAULT_BARK_TRUST_THRESHOLD - 0.01 }],
      { matchDropdownLabel }),
    suggestions
  );
  // Missing matchDropdownLabel dependency also disables fusion defensively.
  assert.equal(fuseBarkSuggestions(suggestions, [{ label: 'Narra', confidence: 0.9 }]), suggestions);
});

test('agreement boosts confidence but is capped and never lowers it', () => {
  const suggestions = [
    { scientificName: 'Pterocarpus indicus', confidence: 0.3, matchedDropdownLabel: 'Narra' },
    { scientificName: 'Mangifera indica', confidence: 0.2, matchedDropdownLabel: 'Mango (Mangifera indica)' },
  ];
  const fused = fuseBarkSuggestions(suggestions, [{ label: 'Narra', confidence: 0.95 }], { matchDropdownLabel });
  assert.equal(fused[0].matchedDropdownLabel, 'Narra');
  assert.equal(fused[0].confidence, DEFAULT_AGREEMENT_CONFIDENCE_CAP);
  assert.deepEqual(fused[0].barkFusion, { agreed: true, barkConfidence: 0.95 });
  // Re-sorted so the boosted suggestion leads.
  assert.equal(fused[1].matchedDropdownLabel, 'Mango (Mangifera indica)');

  // A bark prediction that would lower confidence (already-higher Pl@ntNet
  // score) must not regress the result.
  const alreadyConfident = [{ scientificName: 'Pterocarpus indicus', confidence: 0.95, matchedDropdownLabel: 'Narra' }];
  const unchanged = fuseBarkSuggestions(alreadyConfident, [{ label: 'Narra', confidence: 0.7 }], { matchDropdownLabel });
  assert.equal(unchanged, alreadyConfident);
});

test('a confident bark prediction synthesizes a capped solo suggestion only when Pl@ntNet found nothing', () => {
  const scientificNameForLabel = (label) => (label === 'Narra' ? 'Pterocarpus indicus' : '');
  const fused = fuseBarkSuggestions([], [{ label: 'Narra', confidence: 0.99 }],
    { matchDropdownLabel, scientificNameForLabel });
  assert.equal(fused.length, 1);
  assert.equal(fused[0].scientificName, 'Pterocarpus indicus');
  assert.equal(fused[0].matchedDropdownLabel, 'Narra');
  assert.equal(fused[0].confidence, DEFAULT_SOLO_CONFIDENCE_CAP);
  assert.deepEqual(fused[0].barkFusion, { agreed: false, barkConfidence: 0.99, soloSource: true });
});

test('a solo suggestion is withheld without a scientific name (both the server gate and the client reject blank names)', () => {
  assert.deepEqual(fuseBarkSuggestions([], [{ label: 'Narra', confidence: 0.99 }], { matchDropdownLabel }), []);
  assert.deepEqual(fuseBarkSuggestions([], [{ label: 'Narra', confidence: 0.99 }],
    { matchDropdownLabel, scientificNameForLabel: () => '' }), []);
});

test('a confident bark prediction never second-guesses a disagreeing Pl@ntNet result', () => {
  const suggestions = [{ scientificName: 'Cocos nucifera', confidence: 0.8, matchedDropdownLabel: 'Coconut' }];
  const fused = fuseBarkSuggestions(suggestions, [{ label: 'Narra', confidence: 0.99 }], { matchDropdownLabel });
  assert.equal(fused, suggestions);
});
