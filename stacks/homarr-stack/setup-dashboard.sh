#!/bin/bash
# Homarr Dashboard Setup Script
# Automates the creation of apps, categories, and widgets

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load .env file if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${GREEN}Loading .env file...${NC}"
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
fi

HOMARR_URL="${HOMARR_URL:-http://192.168.31.5:7575}"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Homarr Dashboard Setup${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Homarr URL: $HOMARR_URL"
echo ""

# Check if API key is provided
if [ -z "$HOMARR_API_KEY" ]; then
    echo -e "${YELLOW}Getting API key from user...${NC}"
    echo "Please enter your Homarr API key:"
    echo "Get it from: $HOMARR_URL/profile/settings"
    read -s -p "API Key: " HOMARR_API_KEY
    echo ""
fi

if [ -z "$HOMARR_API_KEY" ]; then
    echo -e "${RED}ERROR: API key is required!${NC}"
    echo "Set it via environment variable: HOMARR_API_KEY=your-key ./setup-dashboard.sh"
    exit 1
fi

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}ERROR: python3 is not installed${NC}"
    exit 1
fi

# Check if requests library is available
if ! python3 -c "import requests" &> /dev/null; then
    echo -e "${YELLOW}requests library not found, setting up venv...${NC}"

    # Create and use virtual environment
    if [ ! -d "$SCRIPT_DIR/.venv" ]; then
        python3 -m venv "$SCRIPT_DIR/.venv"
    fi

    # Activate venv and install requests
    source "$SCRIPT_DIR/.venv/bin/activate"
    pip install --quiet requests

    # Run Python script with venv
    python "$SCRIPT_DIR/setup-homarr.py"
    exit 0
fi

# Export variables for Python script
export HOMARR_URL
export HOMARR_API_KEY

# Run Python script
python3 "$SCRIPT_DIR/setup-homarr.py"
