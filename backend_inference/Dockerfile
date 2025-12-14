# Dockerfile for backend_inference (FastAPI)
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt || true
# we allow pip to fail for heavy packages on constrained hosts; server falls back to simple mode

COPY . /app

ENV PYTHONUNBUFFERED=1
EXPOSE 8000
CMD ["python", "app.py"]
