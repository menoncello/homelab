# Chatterbox Audiobook Generator Stack

## Overview

**Chatterbox Audiobook Generator** - State-of-the-art open-source multilingual TTS with Gradio Web UI for audiobook creation.

Based on [psdwizzard/chatterbox-Audiobook](https://github.com/psdwizzard/chatterbox-Audiobook), featuring professional voice cloning and volume normalization.

### Key Features

- **Gradio Web UI** - User-friendly interface for audiobook generation
- **23 languages** supported with zero-shot voice cloning
- **GPU-accelerated** inference using NVIDIA CUDA
- **Voice cloning** with as little as 5 seconds of audio
- **Professional audio normalization** for broadcast-quality output
- **MIT licensed** - fully open source

### Hardware Requirements

| Component | Minimum | Recommended | Homelab |
|-----------|---------|-------------|----------|
| GPU VRAM | 6GB | 8-16GB | **8GB (RTX 3070ti)** |
| RAM | 8GB | 16GB+ | **64GB** |
| Storage | 50GB | 240GB+ | **NVMe SSD** |

### Language Support

Chatterbox Multilingual supports 23 languages including:
- English (en), Portuguese (pt), Spanish (es)
- French (fr), German (de), Italian (it)
- Japanese (ja), Korean (ko), Chinese (zh)
- Russian (ru), Dutch (nl), Polish (pl)
- And 11 more...

## Deployment

### Prerequisites

```bash
# Verify GPU is available on pop-os
nvidia-smi

# Verify NVIDIA Container Runtime
docker info | grep nvidia

# Verify network exists
docker network ls | grep homelab-net
```

### Deploy Stack

```bash
# From stack directory
cd stacks/chatterbox-stack

# Create volume directories
sudo mkdir -p /data/docker/chatterbox/{huggingface,voices}
sudo chown -R 1000:1000 /data/docker/chatterbox/

# Create output directory
sudo mkdir -p /media/audiobooks
sudo chown -R 1000:1000 /media/audiobooks

# Build and deploy stack (builds image from Dockerfile)
docker stack deploy -c docker-compose.yml chatterbox-stack
```

### Verify Deployment

```bash
# Check service status
docker service ps chatterbox-stack_chatterbox-audiobook

# View logs
docker service logs -f chatterbox-stack_chatterbox-audiobook

# Test Web UI
curl http://192.168.31.75:7861/

# Test via Traefik (after proxy config)
curl http://chatterbox.homelab.local
```

## Usage

### Web UI

Access the Gradio web interface at:
- **Internal:** http://192.168.31.75:7861
- **Via Traefik:** http://chatterbox.homelab.local (after proxy configuration)

#### Features:
1. **Text to Speech** - Convert any text to natural-sounding audio
2. **Voice Cloning** - Upload 5-60 seconds of audio to clone a voice
3. **Audiobook Library** - Browse and download generated audiobooks

### Voice Cloning

**Best practices for voice cloning:**
- Use 5-60 seconds of clear speech
- WAV or MP3 format recommended
- Minimal background noise
- Consistent speaking style

Place custom voice samples in:
```
/data/docker/chatterbox/voices/
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `America/Sao_Paulo` | Timezone |
| `NVIDIA_VISIBLE_DEVICES` | `all` | GPU devices to expose |
| `NVIDIA_DRIVER_CAPABILITIES` | `compute,video,utility,graphics` | Driver features |
| `GRADIO_SERVER_NAME` | `0.0.0.0` | Gradio server bind address |
| `MODEL_NAME` | `resemble-ai/chatterbox-multilingual` | HuggingFace model |

### Volume Paths

| Volume | Host Path | Purpose |
|--------|-----------|---------|
| `chatterbox-huggingface` | `/data/docker/chatterbox/huggingface` | HuggingFace model cache |
| `chatterbox-voices` | `/data/docker/chatterbox/voices` | Custom voice profiles |
| `/app/output` | `/media/audiobooks` | Generated audiobook files |

## Build Details

### Docker Image

Uses **bhimrazy/chatterbox-tts** from Docker Hub:
- Wraps Chatterbox TTS in a scalable API using LitServe
- Supports zero-shot voice cloning and emotion control
- MIT-licensed and production-ready

The image is pulled automatically from Docker Hub during deployment:
```bash
docker stack deploy -c docker-compose.yml chatterbox-stack
```

## Resources

### Project Links
- **Docker Image:** [bhimrazy/chatterbox-tts](https://hub.docker.com/r/bhimrazy/chatterbox-tts)
- **Chatterbox Core:** [resemble-ai/chatterbox](https://github.com/resemble-ai/chatterbox)
- **Documentation:** [chatterboxtts.com/docs](https://chatterboxtts.com/docs)

### Related Projects
- [devnen/Chatterbox-TTS-Server](https://github.com/devnen/Chatterbox-TTS-Server) - Alternative with OpenAI API
- [dwain-barnes/chatterbox-streaming-api-docker](https://github.com/dwain-barnes/chatterbox-streaming-api-docker) - Streaming implementation

### Articles
- [Chatterbox vs ElevenLabs Comparison](https://www.resemble.ai/introducing-chatterbox-multilingual-open-source-tts-for-23-languages/)
- [Best Open Source TTS Models 2025](https://www.resemble.ai/best-open-source-text-to-speech-models/)

## Troubleshooting

### GPU Not Detected

```bash
# Check GPU passthrough
docker exec $(docker ps -q -f name=chatterbox) nvidia-smi

# Check service logs
docker service logs chatterbox-stack_chatterbox-audiobook
```

### Service Not Starting

```bash
# Verify volume permissions
ls -la /data/docker/chatterbox/

# Check resource constraints
docker service inspect chatterbox-stack_chatterbox-audiobook | grep -A 10 "Resources"

# Check build logs
docker service logs chatterbox-stack_chatterbox-audiobook --tail 100
```

### Poor Performance

```bash
# Verify GPU is being used
nvidia-smi dmon -s u

# Check memory limits
docker stats chatterbox-stack_chatterbox-audiobook
```

### Gradio UI Not Loading

```bash
# Check if Gradio is running
docker service logs chatterbox-stack_chatterbox-audiobook | grep -i gradio

# Verify port accessibility
curl http://localhost:7860/
```

## Maintenance

### Update Service

```bash
# Pull latest image
docker pull bhimrazy/chatterbox-tts:latest

# Redeploy
cd stacks/chatterbox-stack
docker stack deploy -c docker-compose.yml chatterbox-stack
```

### Clean Model Cache

```bash
# Remove cached HuggingFace models to free space
sudo rm -rf /data/docker/chatterbox/huggingface/*
docker service update --force chatterbox-stack_chatterbox-audiobook
```

### Backup Voice Profiles

```bash
# Backup custom voices
tar czf chatterbox-voices-backup-$(date +%Y%m%d).tar.gz \
  /data/docker/chatterbox/voices/
```

---

**Stack:** `chatterbox-stack`
**Service:** `chatterbox-audiobook`
**Image:** `bhimrazy/chatterbox-tts:latest` (Docker Hub)
**Placement:** `node.labels.gpu == true` (pop-os)
**Network:** `homelab-net`
**Port:** 7861 (published) / 8000 (container - LitServe API)
