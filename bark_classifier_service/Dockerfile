# Serves the fine-tuned bark classifier only — PyTorch/torchvision (needed
# only for train.py) are deliberately excluded to keep this image small.
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
# bark_classifier.onnx and bark_classifier.labels.json are produced by
# train.py (see README.md) and must be copied in before building the image.
COPY bark_classifier.onnx .
COPY bark_classifier.labels.json .

ENV PORT=8080
EXPOSE 8080

CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT}"]
