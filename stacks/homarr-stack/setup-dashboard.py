#!/usr/bin/env python3
"""
Homarr Dashboard Automation Script
Configures Homarr dashboard with all homelab services, categories, and widgets

Auto-creates virtual environment if needed.

Usage:
    1. Copy .env.example to .env
    2. Edit .env with your Homarr URL and API key
    3. Run: ./setup-dashboard.py
"""

import os
import sys
import json
import time
import subprocess

# Try to import dependencies, install if needed
try:
    import requests
except ImportError:
    print("📦 Installing dependencies...")
    subprocess.check_call([
        sys.executable, "-m", "pip", "install", "-q",
        "--no-warn-script-location", "--disable-pip-version-check",
        "--user", "requests"
    ])
    import requests

# Simple .env parser (no dotenv dependency)
def load_env():
    env_vars = {}
    env_file = os.path.join(os.path.dirname(__file__), '.env')
    if os.path.exists(env_file):
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip()
    return env_vars

# Load environment variables
env = load_env()
HOMARR_URL = env.get("HOMARR_URL", "http://192.168.31.5:7575")
HOMARR_API_KEY = env.get("HOMARR_API_KEY")

if not HOMARR_API_KEY:
    print("❌ Error: HOMARR_API_KEY not found in .env file")
    print("Please create a .env file with your Homarr API key:")
    print("  HOMARR_URL=http://192.168.31.5:7575")
    print("  HOMARR_API_KEY=your_api_key_here")
    exit(1)

# API headers
headers = {
    "Authorization": f"Bearer {HOMARR_API_KEY}",
    "Content-Type": "application/json"
}

# Base URL for API
API_BASE = f"{HOMARR_URL}/api"

# ============================================
# CONFIGURATION
# ============================================

CATEGORIES = [
    {"name": "Media", "color": "#3b82f6", "icon": "mdi:play-circle"},
    {"name": "Automation", "color": "#8b5cf6", "icon": "mdi:robot"},
    {"name": "Requests", "color": "#ec4899", "icon": "mdi:help-circle"},
    {"name": "Infrastructure", "color": "#10b981", "icon": "mdi:server"},
    {"name": "Downloads", "color": "#f59e0b", "icon": "mdi:download"},
    {"name": "Books", "color": "#06b6d4", "icon": "mdi:book"},
    {"name": "Tools", "color": "#6366f1", "icon": "mdi:toolbox"},
]

APPS = [
    # Media
    {
        "name": "Jellyfin",
        "url": "http://jellyfin:8096",
        "icon": "mdi:play-circle",
        "category": "Media",
        "integrationType": "jellyfin",
        "properties": {
            "apiKey": "none",  # User will configure
        }
    },
    {
        "name": "Audiobookshelf",
        "url": "http://audiobookshelf:80",
        "icon": "mdi:book-open-variant",
        "category": "Media",
    },
    {
        "name": "Kavita",
        "url": "http://kavita:5000",
        "icon": "mdi:book-multiple",
        "category": "Books",
    },

    # Automation (ARR Suite)
    {
        "name": "Sonarr",
        "url": "http://sonarr:8989",
        "icon": "mdi:television",
        "category": "Automation",
        "integrationType": "sonarr",
        "properties": {
            "apiKey": "none",
        }
    },
    {
        "name": "Radarr",
        "url": "http://radarr:7878",
        "icon": "mdi:movie",
        "category": "Automation",
        "integrationType": "radarr",
        "properties": {
            "apiKey": "none",
        }
    },
    {
        "name": "Lidarr",
        "url": "http://lidarr:8686",
        "icon": "mdi:music",
        "category": "Automation",
        "integrationType": "lidarr",
        "properties": {
            "apiKey": "none",
        }
    },
    {
        "name": "Bazarr",
        "url": "http://bazarr:6767",
        "icon": "mdi:subtitles",
        "category": "Automation",
    },
    {
        "name": "Prowlarr",
        "url": "http://prowlarr:9696",
        "icon": "mdi:magnify",
        "category": "Automation",
    },
    {
        "name": "Jackett",
        "url": "http://jackett:9117",
        "icon": "mdi:search-web",
        "category": "Automation",
    },

    # Books
    {
        "name": "Listenarr",
        "url": "http://listenarr:8988",
        "icon": "mdi:headphones",
        "category": "Books",
    },
    {
        "name": "Stacks",
        "url": "http://stacks:7788",
        "icon": "mdi:book-search",
        "category": "Books",
    },

    # Requests
    {
        "name": "Jellyseerr",
        "url": "http://jellyseerr:5055",
        "icon": "mdi:help-circle",
        "category": "Requests",
        "integrationType": "overseerr",
        "properties": {
            "apiKey": "none",
        }
    },

    # Downloads
    {
        "name": "qBittorrent",
        "url": "http://transmission:9091",
        "icon": "mdi:download",
        "category": "Downloads",
        "integrationType": "qBittorrent",
        "properties": {
            "username": "admin",
            "password": "change_me",  # User will configure
        }
    },

    # Infrastructure
    {
        "name": "Nginx Proxy Manager",
        "url": "http://192.168.31.5:81",
        "icon": "mdi:nginx",
        "category": "Infrastructure",
    },
    {
        "name": "Pi-hole",
        "url": "http://pihole:8053/admin",
        "icon": "mdi:pi-hole",
        "category": "Infrastructure",
        "integrationType": "pihole",
        "properties": {
            "apiKey": "none",
        }
    },

    # Tools
    {
        "name": "n8n",
        "url": "http://n8n:5678",
        "icon": "mdi:workflow",
        "category": "Tools",
    },
    {
        "name": "eBook2Audiobook",
        "url": "http://ebook2audiobook:7860",
        "icon": "mdi:text-to-speech",
        "category": "Tools",
    },
    {
        "name": "TTS WebUI",
        "url": "http://ttswebui:7770",
        "icon": "mdi:voice",
        "category": "Tools",
    },
    {
        "name": "Chatterbox",
        "url": "http://chatterbox:5123",
        "icon": "mdi:chat",
        "category": "Tools",
    },
]

WIDGETS = [
    # System Statistics
    {
        "type": "dashDot",
        "properties": {
            "cpuMultiCore": True,
            "showCpu": True,
            "showMemory": True,
            "showFileSystem": False,
            "showNetwork": True,
            "useCustomUrl": False,
        }
    },
    {
        "type": "healthMonitoring",
        "properties": {
            "frequentUpdates": False,
        }
    },

    # Weather
    {
        "type": "weather",
        "properties": {
            "defaultCity": "Sao Paulo",
            "latitude": -23.5505,
            "longitude": -46.6333,
            "temperatureUnit": "celsius",
            "windSpeedUnit": "kmh",
            "timeFormat": "24h",
        }
    },

    # RSS Feed - Homelab News
    {
        "type": "rss",
        "properties": {
            "feedUrl": "https://www.reddit.com/r/homelab/new/.rss",
            "feedName": "Homelab News",
            "refreshTime": 60,
            "listAmount": 5,
        }
    },

    # Date/Time
    {
        "type": "date",
        "properties": {
            "dateFormat": "DD/MM/YYYY",
            "timeFormat": "HH:mm:ss",
            "timezone": "America/Sao_Paulo",
            "showDate": True,
            "showTime": True,
            "showSeconds": True,
        }
    },
]

# ============================================
# API FUNCTIONS
# ============================================

def make_request(method, endpoint, data=None):
    """Make API request to Homarr"""
    url = f"{API_BASE}/{endpoint}"

    try:
        if method == "GET":
            response = requests.get(url, headers=headers, timeout=10)
        elif method == "POST":
            response = requests.post(url, headers=headers, json=data, timeout=10)
        elif method == "PUT":
            response = requests.put(url, headers=headers, json=data, timeout=10)
        elif method == "DELETE":
            response = requests.delete(url, headers=headers, timeout=10)
        else:
            raise ValueError(f"Unknown method: {method}")

        response.raise_for_status()
        return response.json() if response.content else {}

    except requests.exceptions.RequestException as e:
        print(f"❌ Request failed: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"   Response: {e.response.text}")
        return None

def get_categories():
    """Get existing categories"""
    result = make_request("GET", "v1/categories")
    return result if isinstance(result, list) else []

def create_category(name, color, icon):
    """Create a new category"""
    data = {
        "name": name,
        "color": color,
        "icon": icon,
    }
    return make_request("POST", "v1/categories", data)

def get_apps():
    """Get existing apps"""
    result = make_request("GET", "v1/apps")
    return result if isinstance(result, list) else []

def create_app(app_data):
    """Create a new app"""
    data = {
        "name": app_data["name"],
        "url": app_data["url"],
        "icon": app_data.get("icon", "mdi:application"),
    }

    # Add category if specified
    if "category" in app_data:
        categories = get_categories()
        for cat in categories:
            if cat["name"] == app_data["category"]:
                data["categoryId"] = cat["id"]
                break

    result = make_request("POST", "v1/apps", data)

    # Add integration if specified
    if result and "integrationType" in app_data:
        app_id = result.get("id")
        if app_id:
            add_integration(app_id, app_data)

    return result

def add_integration(app_id, app_data):
    """Add integration to an app"""
    integration_type = app_data.get("integrationType")
    if not integration_type:
        return

    data = {
        "type": integration_type,
        "properties": app_data.get("properties", {}),
    }

    return make_request("POST", f"v1/apps/{app_id}/integrations", data)

def create_board_config():
    """Create or update board configuration with widgets"""
    # Get board ID (usually 1 for default board)
    boards = make_request("GET", "v1/boards")
    if not boards or len(boards) == 0:
        print("❌ No boards found")
        return False

    board_id = boards[0]["id"]

    # Get current config
    config = make_request("GET", f"v1/boards/{board_id}/config")
    if not config:
        config = {"customization": {"layout": []}, "apps": [], "widgets": []}

    # Add widgets to config
    for widget in WIDGETS:
        widget_data = {
            "type": widget["type"],
            "properties": widget["properties"],
            "id": f"{widget['type']}_{int(time.time())}",
        }

        if "widgets" not in config:
            config["widgets"] = []
        config["widgets"].append(widget_data)

    # Update board config
    result = make_request("PUT", f"v1/boards/{board_id}/config", config)
    return result is not None

# ============================================
# MAIN SETUP
# ============================================

def setup_categories():
    """Create all categories"""
    print("\n📁 Setting up categories...")

    existing = get_categories()
    existing_names = {cat["name"] for cat in existing}

    created = 0
    for cat in CATEGORIES:
        if cat["name"] in existing_names:
            print(f"   ✓ Category '{cat['name']}' already exists")
        else:
            result = create_category(cat["name"], cat["color"], cat["icon"])
            if result:
                print(f"   ✅ Created category: {cat['name']}")
                created += 1
            else:
                print(f"   ❌ Failed to create category: {cat['name']}")

    print(f"   Created {created} new categories")
    return True

def setup_apps():
    """Create all apps"""
    print("\n🚀 Setting up apps...")

    existing = get_apps()
    existing_names = {app["name"] for app in existing}

    created = 0
    for app in APPS:
        if app["name"] in existing_names:
            print(f"   ✓ App '{app['name']}' already exists")
        else:
            result = create_app(app)
            if result:
                print(f"   ✅ Created app: {app['name']}")
                created += 1
            else:
                print(f"   ❌ Failed to create app: {app['name']}")

    print(f"   Created {created} new apps")
    return True

def setup_widgets():
    """Create all widgets"""
    print("\n📊 Setting up widgets...")

    result = create_board_config()
    if result:
        print(f"   ✅ Added {len(WIDGETS)} widgets")
    else:
        print(f"   ❌ Failed to add widgets")

    return result

def print_integration_instructions():
    """Print instructions for configuring integrations"""
    print("\n" + "="*60)
    print("📝 INTEGRATION CONFIGURATION REQUIRED")
    print("="*60)
    print("\nSome integrations need API keys. Configure them in Homarr:\n")

    integrations_needed = [
        ("Sonarr", "http://sonarr:8989", "Settings → General → API Key"),
        ("Radarr", "http://radarr:7878", "Settings → General → API Key"),
        ("Lidarr", "http://lidarr:8686", "Settings → General → API Key"),
        ("qBittorrent", "http://transmission:9091", "Tools → Options → Web UI"),
        ("Pi-hole", "http://pihole:8053", "Settings → API"),
        ("Jellyfin", "http://jellyfin:8096", "Settings → API Keys"),
    ]

    for service, url, instructions in integrations_needed:
        print(f"\n{service}:")
        print(f"   URL: {url}")
        print(f"   API Key: {instructions}")

    print("\n" + "="*60)
    print("💡 TIP: Use Docker service names (not IPs) for internal URLs!")
    print("="*60 + "\n")

def main():
    """Main setup function"""
    print("="*60)
    print("🏠 HOMARR DASHBOARD AUTOMATION")
    print("="*60)
    print(f"\nTarget: {HOMARR_URL}")

    # Test connection
    print("\n🔌 Testing connection...")
    boards = make_request("GET", "v1/boards")
    if not boards:
        print("❌ Cannot connect to Homarr. Please check:")
        print("   1. Homarr is running")
        print("   2. HOMARR_URL is correct")
        print("   3. HOMARR_API_KEY is valid")
        print("\nGet API key from: Profile → Settings → API Keys")
        return False

    print(f"✅ Connected! Found {len(boards)} board(s)")

    # Setup
    success = True
    success &= setup_categories()
    success &= setup_apps()
    success &= setup_widgets()

    if success:
        print("\n" + "="*60)
        print("✅ SETUP COMPLETE!")
        print("="*60)
        print(f"\n🌐 Open your dashboard: {HOMARR_URL}")
        print("\nNext steps:")
        print("   1. Arrange apps by dragging them")
        print("   2. Configure integration API keys (see below)")
        print("   3. Customize widget settings")

        print_integration_instructions()
    else:
        print("\n❌ Setup completed with errors. Check the output above.")

    return success

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Setup cancelled by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
