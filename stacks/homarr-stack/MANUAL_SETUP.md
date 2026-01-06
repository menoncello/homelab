# Homarr Manual Setup Guide

## Quick Setup (5-10 minutes)

### Step 1: Access Homarr
Open: http://192.168.31.5:7575

### Step 2: Create Categories First
1. Click **Manage** → **Categories**
2. Create these categories with colors:

| Name | Color | Hex |
|------|-------|-----|
| Media | Blue | #3b82f6 |
| Automation | Purple | #8b5cf6 |
| Requests | Pink | #ec4899 |
| Infrastructure | Green | #10b981 |
| Downloads | Orange | #f59e0b |
| Books | Cyan | #06b6d4 |
| Tools | Indigo | #6366f1 |

### Step 3: Add Apps Quickly
Use the **Import from URL** feature if available, or add each app:

1. Click **Manage** → **Apps**
2. Click **New App**
3. Use the table below to add all services

---

## All Services to Add

### Media (Category: Media)
- **Jellyfin**: http://192.168.31.5:8096
- **Audiobookshelf**: http://192.168.31.5:8080

### Automation (Category: Automation)
- **Sonarr**: http://192.168.31.5:8989
- **Radarr**: http://192.168.31.5:7878
- **Lidarr**: http://192.168.31.5:8686
- **Bazarr**: http://192.168.31.5:6767
- **Prowlarr**: http://192.168.31.5:9696
- **Jackett**: http://192.168.31.5:9117

### Books (Category: Books)
- **Kavita**: http://192.168.31.5:5000
- **Listenarr**: http://192.168.31.5:8988
- **LazyLibrarian**: http://192.168.31.5:5299

### Requests (Category: Requests)
- **Jellyseerr**: http://192.168.31.5:5055
- **AudioBookRequest**: http://192.168.31.5:8000

### Downloads (Category: Downloads)
- **qBittorrent**: http://192.168.31.5:9091

### Infrastructure (Category: Infrastructure)
- **Nginx Proxy Manager**: http://192.168.31.5:81
- **Pi-hole**: http://192.168.31.5:8053

### Tools (Category: Tools)
- **n8n**: http://192.168.31.5:5678
- **ebook2audiobook**: http://192.168.31.5:7860

---

## After Adding Apps

### Configure Integrations (Optional)

For services that support Homarr integration:

1. **Sonarr/Radarr/Lidarr**:
   - Open the app in Homarr
   - Click the 3 dots → Integration
   - Enable Sonarr/Radarr/Lidarr integration
   - API Key: Get from Settings → API Key in the respective service
   - URL: Use `http://service-name:port` (e.g., `http://sonarr:8989`)

2. **qBittorrent**:
   - Enable qBittorrent integration
   - Get API key from qBittorrent Tools → Options → Web UI

3. **Pi-hole**:
   - Enable Pi-hole integration
   - API Key: Get from Settings → API in Pi-hole

---

## Tips

- Icons are auto-detected from the app name
- You can drag and drop to rearrange
- Create a "Dynamic Section" to group related apps
- Use "Edit Mode" to organize your board

---

## Alternative: Bookmark Import

Some users have success importing bookmarks. Try:

1. Export your browser bookmarks to HTML
2. Use a bookmark-to-homarr converter tool

Or use the JSON config in `configs/default-dashboard.json` as a reference.
