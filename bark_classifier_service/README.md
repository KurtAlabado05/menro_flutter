# Bark/trunk species classifier (optional Pl@ntNet fusion signal)

Pl@ntNet's bark-organ recognition is noticeably weaker than its leaf
recognition — bark is a texture-classification problem, closer to fabric or
material recognition than the shape/color matching Pl@ntNet is strongest
at. This service is a small, self-hosted model trained to recognize the 17
species this app's permit dropdown now supports (see
[`labels.json`](./labels.json)'s `dropdown_labels`) — a closed problem, not
an open-ended "identify any tree species from bark" problem. That scope is
what makes it realistic to train and maintain yourself.

It is **not a replacement** for Pl@ntNet. The Cloud Function
(`functions/bark_species_classifier.mjs`, wired up in `functions/index.js`)
calls this service as an optional second opinion and fuses it with
Pl@ntNet's result:

- If this service agrees with Pl@ntNet's already-proposed species, it can
  raise Pl@ntNet's confidence above the acceptance threshold.
- If Pl@ntNet finds nothing at all, this service can offer its own
  suggestion (clearly flagged as bark-only, and capped at a lower
  confidence than an agreement).
- It can never override or outrank a confident Pl@ntNet result that
  disagrees with it.
- If this service is not deployed, unreachable, or slow, the whole
  identification flow falls back to today's Pl@ntNet-only behavior —
  nothing breaks.

## 0. Why the model trains on 18 classes but only reports 17

A pure fixed-class model has no way to say "this isn't any of my known
species" — softmax always forces the probabilities across its classes to
sum to 1, so a totally unrelated photo (a leaf close-up, a blurry non-bark
shot, some other tree entirely) still gets confidently assigned to
whichever known class it looks *least unlike*. That's exactly the kind of
wrong-but-confident guess this fusion was built to avoid.

So `train.py` / `labels.json` add an 18th, deliberately-excluded class:

| # | Class (folder name) | Reported dropdown label | Category |
|---|---|---|---|
| 0 | `Mahogany` | Mahogany | Exotic Plantation |
| 1 | `Mango` | Mango (Mangifera indica) | Agricultural/Fruit |
| 2 | `Gmelina` | Gmelina | Exotic Plantation |
| 3 | `Acacia` | Acacia | Urban/Roadside |
| 4 | `Narra` | Narra | Premium Hardwood |
| 5 | `Ipil_Ipil` | Ipil-Ipil | Invasive/Fuelwood |
| 6 | `Coconut` | Coconut | Agricultural/Palm |
| 7 | `White_Lauan` | White Lauan | Native — Philippine Mahogany/Dipterocarp |
| 8 | `Guijo` | Guijo | Native — Philippine Mahogany/Dipterocarp |
| 9 | `Apitong` | Apitong | Native — Philippine Mahogany/Dipterocarp |
| 10 | `Red_Lauan` | Red Lauan | Native — Philippine Mahogany/Dipterocarp |
| 11 | `Mayapis` | Mayapis | Native — Philippine Mahogany/Dipterocarp |
| 12 | `Tindalo` | Tindalo | Native — Ultra-Premium Protected |
| 13 | `Bolongeta` | Bolongeta | Native — Ultra-Premium / Native Ebony |
| 14 | `Malaikmo` | Malaikmo | Native — Common Watershed Canopy |
| 15 | `Bayanti` | Bayanti | Native — Common Watershed Canopy |
| 16 | `Malatanglin` | Malatanglin | Native — Common Watershed Canopy |
| 17 | `Unknown_Noise` | *(not reported)* | Background/garbage — fail-safe reject class |

Only `Unknown_Noise` is excluded from `/predict`'s response — it exists
purely as training signal so the model learns to abstain on genuinely
unrelated photos instead of mis-assigning them to one of the 17 real
species. `app.py` filters `/predict`'s response down to the classes listed
in `labels.json`'s `dropdown_labels`, so the HTTP contract the fusion
module relies on never changes regardless of how many reject-only classes
are trained.

**Scientific-name verification note:** the 10 native species' scientific
names were researched and cross-checked against Wikipedia, GBIF's
vernacular-name index, and StuartXchange (a widely-cited Philippine plant
database). 7 resolved with high confidence; 3 (**Mayapis**, **Malaikmo**,
**Malatanglin**) have genuine regional naming ambiguity in Philippine
botanical literature — see the `DROPDOWN_ALIASES` comments in
`functions/index.js` / `cloudflare-worker/src/index.js` and
`TreeSpeciesAliases.dropdownToAliases` in
`lib/core/constants/tree_species_aliases.dart` for the specifics and the
alternate scientific names listed to cover that ambiguity. If a permit
case ever legally hinges on one of these three, confirm the species
in the field rather than relying solely on the automated match.

## 1. Collecting training photos

You need real bark/trunk photos labeled with one of the 18 classes in
`labels.json`. Realistic sources, roughly in order of value:

1. **Your own app's submissions.** Tree-cutting permit applications already
   collect tree photos, and inspection officers record the verified species
   and trunk diameter. This is the best possible training data — same
   camera types, same region, same actual species you need to recognize —
   but you must only use it with proper data-governance/consent review
   (this is municipal/citizen data) and you should still have someone
   confirm each photo is actually a bark/trunk close-up before using it as
   a label.
2. **iNaturalist** (`inaturalist.org`) and **GBIF** (`gbif.org`) — both
   host large numbers of CC-licensed, research-grade observation photos
   searchable by scientific name (e.g. `Pterocarpus indicus`, `Swietenia
   macrophylla`, `Cocos nucifera`, or the native species' scientific names).
   Filter for photos that are actually bark/trunk close-ups (most
   citizen-science photos are flowers/leaves/full habit, so expect to sift
   through a lot — this is manual curation work, budget real time for it).
   Always keep the license/attribution metadata for any image you keep.
3. **Field collection.** If inspectors or volunteers can take a batch of
   dedicated bark reference photos per species (ideally 100–300+ each,
   varying angle/lighting/moisture), that will outperform scraped photos in
   practice. For `Unknown_Noise`, collect a varied grab-bag: leaf close-ups,
   random non-tree objects, blurry/out-of-focus shots, and bark of any tree
   species *not* in this list — variety matters more than volume here,
   since its job is to teach the model what "none of the above" looks like.

Coconut is a palm, not a woody tree — its "bark" is actually a fibrous
trunk texture, visually very different from the other species, so it
should be easy for the model to separate out and a good first species to
collect to sanity-check your pipeline end-to-end.

Organize photos into `data/<label>/*.jpg` using the exact label spelling
from `labels.json` (see `data_sample/` for the expected folder layout).

## 2. Training

```bash
python -m venv .venv
. .venv/Scripts/activate   # or `source .venv/bin/activate` on macOS/Linux
pip install -r requirements.txt -r requirements-train.txt

python train.py --data-dir ./data --arch mobilenet_v3_small --epochs 15 \
    --out bark_classifier.onnx
```

- Prefer `mobilenet_v3_small` (the default) — smaller, faster, and in
  published bark-classification benchmarks small CNNs reach 93–97% accuracy
  on similar closed-set problems. Use `resnet18` as a larger/slower
  alternative if accuracy is insufficient.
- A free Colab GPU runtime is enough for this; a local CPU will also work,
  just slower.
- The script warns you if validation accuracy is low (<70%) or if any
  label from `labels.json` has no training images at all — don't deploy
  until those warnings are gone. This applies to all 18 classes, including
  `Unknown_Noise` — if it has too few/too uniform images, the model will
  still over-confidently guess one of the other 17 classes on unrelated
  photos.
- Output: `bark_classifier.onnx` and `bark_classifier.labels.json` (the
  exact class order the model was trained with — required by `app.py`).

## 3. Running locally

```bash
pip install -r requirements.txt
uvicorn app:app --reload --port 8080

curl -F "image=@/path/to/test_bark_photo.jpg" http://localhost:8080/predict
# {"predictions":[{"label":"Narra","confidence":0.93}, ...]}
```

Only the 17 dropdown species ever appear in `/predict`'s response, even
though the model was trained on 18 classes — see section 0.

## 4. Deploying to Cloud Run

```bash
gcloud run deploy bark-species-classifier \
  --source . \
  --region <your-region> \
  --allow-unauthenticated \
  --memory 1Gi \
  --min-instances 0 \
  --max-instances 3
```

`--allow-unauthenticated` is simplest to start; if you want to lock it down,
switch to `--no-allow-unauthenticated` and have the Cloud Function
authenticate with a service-to-service ID token instead — this is not yet
wired up in `bark_species_classifier.mjs`, so treat the open endpoint as a
starting point, not a permanent choice, if the URL could otherwise leak.

`--min-instances 0` means it scales to zero and costs nothing when idle —
appropriate for a low/moderate-volume municipal app — at the cost of a cold
start (a few seconds) on the first request after idling. Raise
`BARK_CLASSIFIER_TIMEOUT_MS` (see below) if cold starts cause timeouts.

Then configure the Cloud Function to call it:

```bash
firebase functions:config:set bark.classifier_url="https://bark-species-classifier-xxxxx.run.app"
# or, if using functions v2 / environment variables directly:
#   BARK_CLASSIFIER_URL=https://bark-species-classifier-xxxxx.run.app
#   BARK_CLASSIFIER_TIMEOUT_MS=8000   (optional, defaults to 8000)
```

Leaving `BARK_CLASSIFIER_URL` unset disables fusion entirely with zero
behavior change — safe to deploy the function before this service exists,
and safe to roll back by unsetting the variable.

## 5. Keeping `labels.json` in sync

`labels.json`'s `dropdown_labels` entries, `DROPDOWN_ALIASES` in
`functions/index.js` and `cloudflare-worker/src/index.js`,
`TreeSpeciesAliases.dropdownToAliases` in
`lib/core/constants/tree_species_aliases.dart`, and
`TreeCuttingFormModel.treeVariants` in
`lib/screens/tree_cutting/tree_cutting_form_model.dart` must always refer
to the same set of permit dropdown labels. If the dropdown ever changes,
update all four, add/update the corresponding `dropdown_labels` entry, and
retrain.

