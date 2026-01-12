# Chatterbox TTS API Stack

## Overview

**Chatterbox TTS API** - FastAPI-powered OpenAI-compatible TTS API with voice cloning and multilingual support.

Based on [travisvn/chatterbox-tts-api](https://github.com/travisvn/chatterbox-tts-api).

### Key Features

- **OpenAI-Compatible API** - Drop-in replacement for OpenAI's TTS API
- **22 languages** supported with language-aware voice cloning
- **GPU-accelerated** inference using NVIDIA CUDA
- **Voice cloning** with 10-30 seconds of audio
- **FastAPI Performance** - High-performance async API
- **Interactive docs** at `/docs`

### Hardware Requirements

| Component | Minimum | Recommended | Homelab |
|-----------|---------|-------------|----------|
| GPU VRAM | 4GB | 8GB+ | **8GB (RTX 3070ti)** |
| RAM | 4GB | 8GB+ | **64GB** |
| Storage | 10GB | 50GB+ | **NVMe SSD** |

### Language Support

22 languages including:
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

# Verify network exists
docker network ls | grep homelab-net
```

### Create Required Directories

```bash
# Create data directories on pop-os
sudo mkdir -p /data/docker/chatterbox/{models,voices}
sudo chown -R 1000:1000 /data/docker/chatterbox/

# Create output directory for audiobooks
sudo mkdir -p /media/audiobooks
sudo chown -R 1000:1000 /media/audiobooks/
```

### Deploy Stack

```bash
# From stack directory
cd stacks/chatterbox-stack

# Deploy stack
docker stack deploy -c media.docker-compose.yml chatterbox-stack
```

### Verify Deployment

```bash
# Check service status
docker service ps chatterbox-stack_chatterbox-api

# View logs
docker service logs -f chatterbox-stack_chatterbox-api

# Test health endpoint
curl http://192.168.31.5:5123/health

# Test via Traefik (after proxy config)
curl http://chatterbox.homelab/health
```

## Usage

### API Endpoints

**Base URL:** http://192.168.31.5:5123

#### Basic Text-to-Speech
```bash
curl -X POST http://192.168.31.5:5123/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"input": "Hello world!"}' \
  --output speech.wav
```

#### Voice Cloning
```bash
curl -X POST http://192.168.31.5:5123/v1/audio/speech/upload \
  -F "input=Hello with my voice!" \
  -F "voice_file=@my_voice.mp3" \
  --output custom_voice.wav
```

#### Voice Library Management
```bash
# Upload voice to library
curl -X POST http://192.168.31.5:5123/voices \
  -F "voice_file=@my_voice.wav" \
  -F "voice_name=my-custom-voice" \
  -F "language=en"

# List voices
curl http://192.168.31.5:5123/voices

# Use voice by name
curl -X POST http://192.168.31.5:5123/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"input": "Hello!", "voice": "my-custom-voice"}' \
  --output output.wav
```

### Interactive Documentation

Access the interactive API documentation:
- **Swagger UI:** http://192.168.31.5:5123/docs
- **ReDoc:** http://192.168.31.5:5123/redoc
- **Via Traefik:** http://chatterbox.homelab/docs

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `America/Sao_Paulo` | Timezone |
| `NVIDIA_VISIBLE_DEVICES` | `all` | GPU visibility |
| `NVIDIA_DRIVER_CAPABILITIES` | `compute,video,utility,graphics` | GPU driver features |

### Volume Paths

| Volume | Host Path | Purpose |
|--------|-----------|---------|
| `chatterbox-models` | `/data/docker/chatterbox/models` | HuggingFace model cache |
| `chatterbox-voices` | `/data/docker/chatterbox/voices` | Voice library |
| `/app/output` | `/media/audiobooks` | Generated audio files |

## Resources

### Project Links
- **GitHub:** [travisvn/chatterbox-tts-api](https://github.com/travisvn/chatterbox-tts-api)
- **Documentation:** [chatterboxtts.com/docs](https://chatterboxtts.com/docs)
- **Docker Hub:** [travisvn/chatterbox-tts-api](https://hub.docker.com/r/travisvn/chatterbox-tts-api)

### API Documentation
- [Complete API Reference](https://chatterboxtts.com/docs#api-endpoints)
- [Voice Library Guide](https://chatterboxtts.com/docs#-voice-library-management)
- [Multilingual Support](https://chatterboxtts.com/docs#-multilingual-support)

## Troubleshooting

### GPU Not Detected

```bash
# Check GPU passthrough
docker exec $(docker ps -q -f name=chatterbox) nvidia-smi

# Check service logs
docker service logs chatterbox-stack_chatterbox-api
```

### Service Not Starting

```bash
# Verify volume directories exist
ls -la /data/docker/chatterbox/

# Check resource constraints
docker service inspect chatterbox-stack_chatterbox-api | grep -A 10 "Resources"
```

### Poor Performance

```bash
# Verify GPU is being used
nvidia-smi dmon -s u

# Check memory limits
docker stats chatterbox-stack_chatterbox-api
```

## Maintenance

### Update Service

```bash
# Pull latest image
docker pull travisvn/chatterbox-tts-api:latest

# Redeploy
cd stacks/chatterbox-stack
docker stack deploy -c media.docker-compose.yml chatterbox-stack
```

### Clean Model Cache

```bash
# Remove cached models to free space
sudo rm -rf /data/docker/chatterbox/models/*
docker service update --force chatterbox-stack_chatterbox-api
```

### Backup Voice Library

```bash
# Backup custom voices
tar czf chatterbox-voices-backup-$(date +%Y%m%d).tar.gz \
  /data/docker/chatterbox/voices/
```

---

**Stack:** `chatterbox-stack`
**Service:** `chatterbox-api`
**Image:** `travisvn/chatterbox-tts-api:latest`
**Placement:** `node.labels.gpu == true` (pop-os)
**Network:** `homelab-net`
**Port:** 5123 (FastAPI)
