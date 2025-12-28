# TTS WebUI Stack

## Overview

**TTS WebUI** - Gradio + React WebUI for Chatterbox TTS and other text-to-speech models.

Based on [rsxdalv/TTS-WebUI](https://github.com/rsxdalv/TTS-WebUI).

### Key Features

- **Chatterbox TTS** - 22 languages with voice cloning
- **Web UI** - Beautiful Gradio and React interfaces
- **Multiple TTS Models** - Bark, Tortoise, XTTSv2, CosyVoice, and more
- **GPU-accelerated** - NVIDIA CUDA support
- **Voice Library** - Manage custom voices
- **Extensions** - Install additional TTS models via web UI
- **OpenAI-Compatible API** - Drop-in replacement for OpenAI's TTS API

### Hardware Requirements

| Component | Minimum | Recommended | Homelab |
|-----------|---------|-------------|----------|
| GPU VRAM | 8GB | 12GB+ | **8GB (RTX 3070ti)** |
| RAM | 8GB | 16GB+ | **64GB** |
| Storage | 20GB | 100GB+ | **NVMe SSD** |

### Supported TTS Models

- **Chatterbox TTS** - Multilingual with voice cloning
- **Bark** - Natural sounding multilingual TTS
- **Tortoise TTS** - High quality multi-speaker TTS
- **XTTSv2** - Coqui's cross-language TTS
- **CosyVoice** - Natural speech synthesis
- **Piper TTS** - Fast, local neural TTS
- And many more via extensions...

## Deployment

### Prerequisites

```bash
# Verify GPU is available on pop-os
nvidia-smi

# Verify network exists
docker network ls | grep homelab-net
```

### Create Required Directories

```bash
# Create data directories on pop-os
sudo mkdir -p /data/docker/tts-webui/{models,voices,db}
sudo chown -R 1000:1000 /data/docker/tts-webui/

# Create output directory for audiobooks
sudo mkdir -p /media/audiobooks
sudo chown -R 1000:1000 /media/audiobooks/
```

### Deploy Stack

```bash
# From stack directory
cd stacks/tts-webui-stack

# Deploy stack
docker stack deploy -c docker-compose.yml tts-webui-stack
```

### Verify Deployment

```bash
# Check service status
docker service ps tts-webui-stack_tts-webui

# View logs (first run will download models, this takes time)
docker service logs -f tts-webui-stack_tts-webui

# Wait for Gradio UI to start (may take 5-10 minutes on first run)
```

## Usage

### Web Interfaces

**Gradio UI** (Recommended for first use):
- **URL:** http://192.168.31.75:7770
- **Via Traefik:** http://ttswebui.homelab.local

**React UI** (Modern interface):
- **URL:** http://192.168.31.75:3000
- **Via Traefik:** http://ttswebui.homelab.local:3000

### First Time Setup

1. **Open Gradio UI** at http://192.168.31.75:7770
2. **Install Chatterbox Extension** (if not pre-installed):
   - Go to Extensions tab
   - Find Chatterbox TTS extension
   - Click Install
   - Restart the service

### Using Chatterbox TTS

1. **Select Chatterbox** model from the dropdown
2. **Enter text** in Portuguese or any of 22 supported languages
3. **Optionally upload** a voice sample for cloning (10-30 seconds)
4. **Click Generate** to create audio
5. **Download** the generated audio file

### Voice Cloning

1. Go to the Voice Library tab
2. Upload your voice sample (MP3/WAV)
3. Name your voice and select language
4. Use your custom voice for TTS generation

### API Access

TTS WebUI also provides an OpenAI-compatible API:

```bash
# Base URL for API
http://192.168.31.75:7778/v1/audio/speech

# Example: Generate speech
curl -X POST http://192.168.31.75:7778/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"input": "Olá, mundo!", "voice": "chatterbox"}' \
  --output speech.wav
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `America/Sao_Paulo` | Timezone |
| `TTS_PORT` | `7770` | Gradio UI port |
| `UI_PORT` | `3000` | React UI port |
| `NVIDIA_VISIBLE_DEVICES` | `all` | GPU visibility |

### Volume Paths

| Volume | Host Path | Purpose |
|--------|-----------|---------|
| `tts-webui-models` | `/data/docker/tts-webui/models` | Model cache |
| `tts-webui-voices` | `/data/docker/tts-webui/voices` | Voice library |
| `tts-webui-db` | `/data/docker/tts-webui/db` | Database |
| `/app/outputs` | `/media/audiobooks` | Generated audio files |

## Resources

### Project Links
- **GitHub:** [rsxdalv/TTS-WebUI](https://github.com/rsxdalv/TTS-WebUI)
- **Documentation:** [TTS WebUI Wiki](https://github.com/rsxdalv/TTS-WebUI/wiki)
- **Docker Image:** [ghcr.io/rsxdalv/tts-webui](https://github.com/rsxdalv/TTS-WebUI#docker-setup)

### Extensions Catalog
- [TTS WebUI Extension Catalog](https://github.com/rsxdalv/TTS-WebUI-Extension-Catalog)

## Troubleshooting

### First Run Takes Long

**Expected behavior:** Models are downloaded on first run (10-15 minutes)

```bash
# Check download progress
docker service logs tts-webui-stack_tts-webui | tail -50
```

### Out of Memory

If you see OOM errors, increase memory limits:

```yaml
resources:
  limits:
    memory: 24G  # Increase from 16G
```

Then redeploy:
```bash
docker stack deploy -c docker-compose.yml tts-webui-stack
```

### Models Not Loading

```bash
# Check if models directory exists and has content
ls -la /data/docker/tts-webui/models/

# Check logs for errors
docker service logs tts-webui-stack_tts-webui | grep -i error
```

### GPU Not Detected

```bash
# Verify GPU passthrough
docker exec $(docker ps -q -f name=tts-webui) nvidia-smi

# Check service logs
docker service logs tts-webui-stack_tts-webui | grep -i cuda
```

## Maintenance

### Update Service

```bash
# Pull latest image
docker pull ghcr.io/rsxdalv/tts-webui:main

# Redeploy
cd stacks/tts-webui-stack
docker stack deploy -c docker-compose.yml tts-webui-stack
```

### Clean Model Cache

```bash
# Remove cached models to free space
sudo rm -rf /data/docker/tts-webui/models/*
docker service update --force tts-webui-stack_tts-webui
```

### Backup Voice Library

```bash
# Backup custom voices
tar czf tts-webui-voices-backup-$(date +%Y%m%d).tar.gz \
  /data/docker/tts-webui/voices/
```

## Integration with Other Services

### Silly Tavern

1. Enable OpenAI API extension in TTS WebUI
2. Configure Silly Tavern TTS endpoint:
   - URL: `http://192.168.31.75:7778/v1/audio/speech`
3. Select Chatterbox as voice model

### Open WebUI

1. Enable OpenAI API extension
2. Add TTS API in Open WebUI settings:
   - Endpoint: `http://192.168.31.75:7778/v1/audio/speech`

---

**Stack:** `tts-webui-stack`
**Service:** `tts-webui`
**Image:** `ghcr.io/rsxdalv/tts-webui:main`
**Placement:** `node.labels.gpu == true` (pop-os)
**Network:** `homelab-net`
**Ports:** 7770 (Gradio), 3000 (React), 7778 (API)
