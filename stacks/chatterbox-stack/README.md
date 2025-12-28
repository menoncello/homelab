# Chatterbox TTS Server Stack

## Overview

**Chatterbox TTS Server** - FastAPI-powered TTS with Web UI, voice cloning, and audiobook support.

Based on [devnen/Chatterbox-TTS-Server](https://github.com/devnen/Chatterbox-TTS-Server).

### Key Features

- **OpenAI-Compatible API** - Drop-in replacement for OpenAI's TTS API
- **22 languages** supported with language-aware voice cloning
- **GPU-accelerated** inference using NVIDIA CUDA
- **Voice cloning** with 10-30 seconds of audio
- **Web UI** for interactive TTS generation at `/`
- **Audiobook support** with chapter/segment processing
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
# Create config and data directories on pop-os
sudo mkdir -p /data/docker/chatterbox/{config.yaml,voices,reference_audio,logs}
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
docker stack deploy -c docker-compose.yml chatterbox-stack
```

### Verify Deployment

```bash
# Check service status
docker service ps chatterbox-stack_chatterbox-server

# View logs
docker service logs -f chatterbox-stack_chatterbox-server

# Test health endpoint
curl http://192.168.31.75:8004/api/ui/initial-data

# Test via Traefik (after proxy config)
curl http://chatterbox.homelab.local/api/ui/initial-data
```

## Usage

### Web UI

Access the web interface at:
- **Direct:** http://192.168.31.75:8004
- **Via Traefik:** http://chatterbox.homelab.local

### API Endpoints

**Base URL:** http://192.168.31.75:8004

#### Basic Text-to-Speech
```bash
curl -X POST http://192.168.31.75:8004/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"input": "Hello world!"}' \
  --output speech.wav
```

#### Voice Cloning
```bash
curl -X POST http://192.168.31.75:8004/v1/audio/speech/upload \
  -F "input=Hello with my voice!" \
  -F "voice_file=@my_voice.mp3" \
  --output custom_voice.wav
```

#### Voice Library Management
```bash
# Upload voice to library
curl -X POST http://192.168.31.75:8004/voices \
  -F "voice_file=@my_voice.wav" \
  -F "voice_name=my-custom-voice" \
  -F "language=en"

# List voices
curl http://192.168.31.75:8004/voices

# Use voice by name
curl -X POST http://192.168.31.75:8004/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"input": "Hello!", "voice": "my-custom-voice"}' \
  --output output.wav
```

### Interactive Documentation

Access the interactive API documentation:
- **Swagger UI:** http://192.168.31.75:8004/docs
- **ReDoc:** http://192.168.31.75:8004/redoc
- **Via Traefik:** http://chatterbox.homelab.local/docs

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
| `chatterbox-hf-cache` | (Docker volume) | HuggingFace model cache |
| `chatterbox-config` | `/data/docker/chatterbox/config.yaml` | Configuration file |
| `chatterbox-voices` | `/data/docker/chatterbox/voices` | Voice library |
| `chatterbox-reference` | `/data/docker/chatterbox/reference_audio` | Reference audio for cloning |
| `/app/outputs` | `/media/audiobooks` | Generated audio files |
| `chatterbox-logs` | `/data/docker/chatterbox/logs` | Application logs |

## Resources

### Project Links
- **GitHub:** [devnen/Chatterbox-TTS-Server](https://github.com/devnen/Chatterbox-TTS-Server)
- **Documentation:** [Chatterbox-TTS-Server README](https://github.com/devnen/Chatterbox-TTS-Server#readme)
- **Docker Hub:** [devnen/chatterbox-tts-server](https://hub.docker.com/r/devnen/chatterbox-tts-server)

### API Documentation
- [Web UI Demo](http://192.168.31.75:8004)
- [FastAPI Docs](http://192.168.31.75:8004/docs)
- [OpenAI API Reference](https://github.com/devnen/Chatterbox-TTS-Server#openai-compatible-api)

## Troubleshooting

### GPU Not Detected

```bash
# Check GPU passthrough
docker exec $(docker ps -q -f name=chatterbox) nvidia-smi

# Check service logs
docker service logs chatterbox-stack_chatterbox-server
```

### Service Not Starting

```bash
# Verify volume directories exist
ls -la /data/docker/chatterbox/

# Check resource constraints
docker service inspect chatterbox-stack_chatterbox-server | grep -A 10 "Resources"
```

### Poor Performance

```bash
# Verify GPU is being used
nvidia-smi dmon -s u

# Check memory limits
docker stats chatterbox-stack_chatterbox-server
```

## Maintenance

### Update Service

```bash
# Pull latest image
docker pull devnen/chatterbox-tts-server:latest

# Redeploy
cd stacks/chatterbox-stack
docker stack deploy -c docker-compose.yml chatterbox-stack
```

### Clean Model Cache

```bash
# Remove cached models to free space (Docker volume)
docker volume rm chatterbox-stack_chatterbox-hf-cache
docker service update --force chatterbox-stack_chatterbox-server
```

### Backup Voice Library

```bash
# Backup custom voices
tar czf chatterbox-voices-backup-$(date +%Y%m%d).tar.gz \
  /data/docker/chatterbox/voices/
```

---

**Stack:** `chatterbox-stack`
**Service:** `chatterbox-server`
**Image:** `devnen/chatterbox-tts-server:latest`
**Placement:** `node.labels.gpu == true` (pop-os)
**Network:** `homelab-net`
**Port:** 8004 (FastAPI + Web UI)
