# Chatterbox Audiobook Generator
# State-of-the-art TTS for audiobook creation with Gradio UI
# Based on: https://github.com/psdwizzard/chatterbox-Audiobook

FROM pytorch/pytorch:2.6.0-cuda12.4-cudnn9-runtime

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    GRADIO_SERVER_NAME=0.0.0.0

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ffmpeg \
    libsndfile1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
# Based on chatterbox-Audiobook requirements
COPY requirements.txt .

# Install Python dependencies
# PyTorch already included in base image
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Install Chatterbox TTS
RUN pip install git+https://github.com/resemble-ai/chatterbox.git

# Copy application files
COPY . .

# Create necessary directories
RUN mkdir -p /app/voices /app/output /app/cache

# Expose Gradio port
EXPOSE 7860

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:7860/ || exit 1

# Run the Gradio app
CMD ["python", "gradio_tts_app_audiobook.py"]
