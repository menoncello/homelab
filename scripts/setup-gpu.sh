#!/bin/bash
# scripts/setup-gpu.sh

echo "Setting up NVIDIA Container Runtime..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

# Install NVIDIA Container Toolkit
echo "Adding NVIDIA repository..."
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-container-runtime/gpgkey | apt-key add -
curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.list | tee /etc/apt/sources.list.d/nvidia-container-runtime.list

# Update and install
echo "Installing NVIDIA Container Runtime..."
apt-get update
apt-get install -y nvidia-container-runtime

# Configure Docker daemon
echo "Configuring Docker daemon for NVIDIA runtime..."
mkdir -p /etc/docker

# Check if daemon.json exists
if [ -f /etc/docker/daemon.json ]; then
    # Backup existing config
    cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
    echo "Backed up existing daemon.json to /etc/docker/daemon.json.backup"
fi

# Write new daemon.json with nvidia runtime
cat > /etc/docker/daemon.json <<'EOF'
{
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
EOF

# Restart Docker
echo "Restarting Docker..."
systemctl restart docker

# Wait for Docker to start
sleep 5

# Verify installation
echo ""
echo "Verifying installation..."
if systemctl is-active --quiet docker; then
    echo "✓ Docker is running"
else
    echo "✗ Docker failed to start"
    exit 1
fi

if docker info | grep -q "nvidia"; then
    echo "✓ NVIDIA runtime is available in Docker"
else
    echo "⚠ Warning: NVIDIA runtime not found in docker info"
fi

if command -v nvidia-smi &> /dev/null; then
    echo "✓ nvidia-smi is available"
    echo ""
    echo "GPU Info:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
else
    echo "⚠ Warning: nvidia-smi not found. Make sure NVIDIA drivers are installed."
fi

echo ""
echo "GPU Runtime setup complete!"
echo "Please verify GPU access with: docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi"
