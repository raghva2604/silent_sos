FROM python:3.11-slim

# Install system dependencies including ffmpeg for audio processing
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY server.py .
COPY stt_multilang.py .
COPY .env* ./

# Set environment variables for Whisper
ENV WHISPER_MODEL=large-v2
ENV WHISPER_DEVICE=cpu
ENV PYTHONUNBUFFERED=1

EXPOSE 8000

# Run uvicorn server
CMD ["python", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
