#!/usr/bin/env python3
"""
Homarr Dashboard Automation Script
Automatically creates apps, categories, and widgets for your homelab services.
"""

import os
import requests
import json
import sys
from urllib.parse import urljoin

# Configuration from environment variables
HOMARR_URL = os.getenv("HOMARR_URL", "http://192.168.31.5:7575")
API_KEY = os.getenv("HOMARR_API_KEY", "")

# Headers for API requests
headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

# Categories to create
CATEGORIES = [
    {"name": "Media", "position": 1, "color": "#3b82f6"},
    {"name": "Automation", "position": 2, "color": "#8b5cf6"},
    {"name": "Requests", "position": 3, "color": "#ec4899"},
    {"name": "Infrastructure", "position": 4, "color": "#10b981"},
    {"name": "Downloads", "position": 5, "color": "#f59e0b"},
    {"name": "Books", "position": 6, "color": "#06b6d4"},
    {"name": "Tools", "position": 7, "color": "#6366f1"}
]

# Apps to create
APPS = [
    # Media
    {"name": "Jellyfin", "url": "http://192.168.31.5:8096", "category": "Media", "icon": "jellyfin"},
    {"name": "Audiobookshelf", "url": "http://192.168.31.5:8080", "category": "Media", "icon": "audiobookshelf"},

    # Automation
    {"name": "Sonarr", "url": "http://192.168.31.5:8989", "category": "Automation", "icon": "sonarr"},
    {"name": "Radarr", "url": "http://192.168.31.5:7878", "category": "Automation", "icon": "radarr"},
    {"name": "Lidarr", "url": "http://192.168.31.5:8686", "category": "Automation", "icon": "lidarr"},
    {"name": "Bazarr", "url": "http://192.168.31.5:6767", "category": "Automation", "icon": "bazarr"},
    {"name": "Prowlarr", "url": "http://192.168.31.5:9696", "category": "Automation", "icon": "prowlarr"},
    {"name": "Jackett", "url": "http://192.168.31.5:9117", "category": "Automation", "icon": "jackett"},

    # Books
    {"name": "Kavita", "url": "http://192.168.31.5:5000", "category": "Books", "icon": "kavita"},
    {"name": "Listenarr", "url": "http://192.168.31.5:8988", "category": "Books", "icon": "listenarr"},
    {"name": "LazyLibrarian", "url": "http://192.168.31.5:5299", "category": "Books", "icon": "lazylibrarian"},

    # Requests
    {"name": "Jellyseerr", "url": "http://192.168.31.5:5055", "category": "Requests", "icon": "jellyseerr"},
    {"name": "AudioBookRequest", "url": "http://192.168.31.5:8000", "category": "Requests", "icon": "audiobook"},

    # Downloads
    {"name": "qBittorrent", "url": "http://192.168.31.5:9091", "category": "Downloads", "icon": "qbittorrent"},

    # Infrastructure
    {"name": "Nginx Proxy Manager", "url": "http://192.168.31.5:81", "category": "Infrastructure", "icon": "nginx"},
    {"name": "Pi-hole", "url": "http://192.168.31.5:8053", "category": "Infrastructure", "icon": "pihole"},

    # Tools
    {"name": "n8n", "url": "http://192.168.31.5:5678", "category": "Tools", "icon": "n8n"},
    {"name": "ebook2audiobook", "url": "http://192.168.31.5:7860", "category": "Tools", "icon": "book"},
]


def api_request(method, endpoint, data=None):
    """Make an API request to Homarr"""
    url = urljoin(HOMARR_URL, f"/api/{endpoint}")
    try:
        if method == "GET":
            response = requests.get(url, headers=headers)
        elif method == "POST":
            response = requests.post(url, headers=headers, json=data)
        elif method == "PATCH":
            response = requests.patch(url, headers=headers, json=data)
        elif method == "DELETE":
            response = requests.delete(url, headers=headers)
        else:
            raise ValueError(f"Unknown method: {method}")

        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return None


def get_categories():
    """Get existing categories"""
    result = api_request("GET", "categories")
    if result:
        return result.get("items", [])
    return []


def get_apps():
    """Get existing apps"""
    result = api_request("GET", "apps")
    if result:
        return result.get("items", [])
    return []


def create_category(name, position, color):
    """Create a new category"""
    print(f"Creating category: {name}")
    data = {
        "name": name,
        "position": position,
        "color": color
    }
    return api_request("POST", "categories", data)


def create_app(name, url, category_name, icon):
    """Create a new app"""
    print(f"Creating app: {name} ({url})")

    # Get category by name
    categories = get_categories()
    category_id = None
    for cat in categories:
        if cat.get("name") == category_name:
            category_id = cat.get("id")
            break

    if not category_id:
        print(f"  Warning: Category '{category_name}' not found, creating it...")
        cat_data = next((c for c in CATEGORIES if c["name"] == category_name), None)
        if cat_data:
            result = create_category(cat_data["name"], cat_data["position"], cat_data["color"])
            if result:
                category_id = result.get("id")

    data = {
        "name": name,
        "url": url,
        "appearance": {
            "iconSize": "medium",
            "position": "default",
            "statusType": "dot",
            "isNameVisible": True
        },
        "network": {
            "enabledStatusChecker": True,
          "statusCodes": ["200", "301", "302", "307", "308"],
            "method": "GET"
        },
        "behaviour": {
            "externalUrl": "",
            "openInNewTab": True
        },
        "integration": {
            "type": None,
            "properties": []
        },
        "categoryId": category_id
    }
    return api_request("POST", "apps", data)


def setup_dashboard():
    """Setup the complete dashboard"""
    print("=" * 50)
    print("Homarr Dashboard Setup")
    print("=" * 50)

    if not API_KEY:
        print("\nERROR: Please set your API_KEY in the script!")
        print("Get your API key from:")
        print(f"  {HOMARR_URL}/profile/settings")
        sys.exit(1)

    # Test connection
    print("\nTesting connection to Homarr...")
    result = api_request("GET", "users")
    if not result:
        print("ERROR: Could not connect to Homarr. Check URL and API key.")
        sys.exit(1)
    print("✓ Connection successful!")

    # Get existing items
    existing_apps = get_apps()
    existing_categories = get_categories()
    existing_app_names = {app.get("name") for app in existing_apps}
    existing_cat_names = {cat.get("name") for cat in existing_categories}

    print(f"\nExisting apps: {len(existing_apps)}")
    print(f"Existing categories: {len(existing_categories)}")

    # Create categories
    print("\n" + "=" * 50)
    print("Creating categories...")
    print("=" * 50)
    for cat in CATEGORIES:
        if cat["name"] not in existing_cat_names:
            create_category(cat["name"], cat["position"], cat["color"])
        else:
            print(f"Category '{cat['name']}' already exists, skipping...")

    # Create apps
    print("\n" + "=" * 50)
    print("Creating apps...")
    print("=" * 50)
    created = 0
    skipped = 0
    for app in APPS:
        if app["name"] not in existing_app_names:
            result = create_app(app["name"], app["url"], app["category"], app["icon"])
            if result:
                created += 1
                print(f"  ✓ Created: {app['name']}")
            else:
                print(f"  ✗ Failed: {app['name']}")
        else:
            skipped += 1
            print(f"  ⊘ Skipped (already exists): {app['name']}")

    print("\n" + "=" * 50)
    print("Summary")
    print("=" * 50)
    print(f"Apps created: {created}")
    print(f"Apps skipped: {skipped}")
    print(f"Total apps: {len(APPS)}")
    print("\n✓ Dashboard setup complete!")
    print(f"\nVisit {HOMARR_URL} to see your dashboard.")


if __name__ == "__main__":
    setup_dashboard()
