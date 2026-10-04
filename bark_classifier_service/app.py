"""Serves the fine-tuned bark/trunk species classifier (see train.py) over a
small REST API, meant to be called by functions/bark_species_classifier.mjs
as an optional fusion signal alongside Pl@ntNet. Deploy this as a Cloud Run
container (see Dockerfile + README.md) and set BARK_CLASSIFIER_URL in your
Cloud Functions environment to its URL.

Contract with the caller (see functions/bark_species_classifier.mjs):
    POST /predict  (multipart/form-data, field name "image")
    -> 200 {"predictions": [{"label": "Narra", "confidence": 0.93}, ...]}

Any other status code (or a timeout) is treated by the caller as "no
opinion" and safely ignored — Pl@ntNet-only behavior is always preserved.

The model (see train.py / labels.json) is trained on 18 classes: 17 permit
dropdown species plus an "Unknown_Noise" background/reject class. Only the
17 dropdown species are ever reported here — the Unknown_Noise class exists
purely so the model can abstain instead of force-fitting an unrelated,
non-bark photo into one of the 17 dropdown buckets. See README.md section 0
for the full rationale.
"""
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image

MODEL_PATH = Path(__file__).parent / "bark_classifier.onnx"
LABELS_PATH = Path(__file__).parent / "bark_classifier.labels.json"
DROPDOWN_LABELS_PATH = Path(__file__).parent / "labels.json"
IMAGE_SIZE = 224
IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)
# Predictions below this are omitted entirely rather than reported as a weak
# top-1 guess — the fusion caller already applies its own, independently
# configurable trust threshold on top of whatever this returns.
MIN_REPORTED_CONFIDENCE = 0.05

app = FastAPI(title="Bark/trunk species classifier")
_session: ort.InferenceSession | None = None
_labels: list[str] = []
# Maps a trained class name (e.g. "Ipil_Ipil") to the permit dropdown label
# the caller expects (e.g. "Ipil-Ipil"). The only class with no entry is
# Unknown_Noise -- it is trained for rejection purposes only and is never
# included in /predict's response. See labels.json's "dropdown_labels".
_dropdown_label_by_class: dict[str, str] = {}


@app.on_event("startup")
def load_model() -> None:
    global _session, _labels, _dropdown_label_by_class
    if not MODEL_PATH.exists() or not LABELS_PATH.exists():
        raise RuntimeError(
            f"Missing {MODEL_PATH.name} or {LABELS_PATH.name}. Run train.py "
            "first and copy its output next to this file (see README.md)."
        )
    _session = ort.InferenceSession(str(MODEL_PATH), providers=["CPUExecutionProvider"])
    _labels = json.loads(LABELS_PATH.read_text())
    _dropdown_label_by_class = json.loads(
        DROPDOWN_LABELS_PATH.read_text()
    ).get("dropdown_labels", {}) if DROPDOWN_LABELS_PATH.exists() else {}


def preprocess(image: Image.Image) -> np.ndarray:
    image = image.convert("RGB").resize((IMAGE_SIZE, IMAGE_SIZE))
    array = np.asarray(image, dtype=np.float32) / 255.0
    array = (array - IMAGENET_MEAN) / IMAGENET_STD
    # HWC -> CHW, add batch dimension.
    array = array.transpose(2, 0, 1)[np.newaxis, ...]
    return array.astype(np.float32)


def softmax(logits: np.ndarray) -> np.ndarray:
    shifted = logits - logits.max()
    exp = np.exp(shifted)
    return exp / exp.sum()


@app.get("/")
def health() -> dict:
    return {
        "status": "ok",
        "labels": _labels,
        "reported_labels": sorted(_dropdown_label_by_class.values()),
    }


@app.post("/predict")
async def predict(image: UploadFile = File(...)) -> dict:
    if _session is None:
        raise HTTPException(status_code=503, detail="Model not loaded.")
    try:
        pil_image = Image.open(image.file)
        pil_image.load()
    except Exception as exc:  # noqa: BLE001 - any decode failure is a 400
        raise HTTPException(status_code=400, detail="Unreadable image.") from exc

    input_tensor = preprocess(pil_image)
    (logits,) = _session.run(["logits"], {"input": input_tensor})
    probabilities = softmax(logits[0])

    # Only ever report the 17 permit dropdown species. Unknown_Noise exists
    # purely to let the model abstain instead of force-fitting an unrelated,
    # non-bark photo into one of the 17 buckets; reporting it would break
    # the caller's dropdown-label matching (see
    # functions/bark_species_classifier.mjs).
    predictions = [
        {"label": _dropdown_label_by_class[label], "confidence": float(confidence)}
        for label, confidence in zip(_labels, probabilities)
        if label in _dropdown_label_by_class and confidence >= MIN_REPORTED_CONFIDENCE
    ]
    predictions.sort(key=lambda p: p["confidence"], reverse=True)
    return {"predictions": predictions}
