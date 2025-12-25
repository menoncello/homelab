# Calibre-Web Automated Stack

All-in-one ebook manager with Anna's Archive integration. Search, download, and read books in one place.

## Access

- **URL:** http://192.168.31.208:8083
- **Default credentials:**
  - Username: `admin`
  - Password: `admin123` (change after first login)

## Features

- **Anna's Archive Search** - Built-in search and download from Anna's Archive
- **Auto Cloudflare Bypass** - No need for FlareSolverr
- **Browse & Read** - Read EPUB, PDF in browser
- **Library Management** - Organize by author, series, tags
- **OPDS** - Access from mobile e-reader apps
- **Auto-Import** - Automatically imports downloaded books

## First Time Setup

```bash
# 1. Create volume directories (on Xeon01)
ssh eduardo@192.168.31.208
sudo mkdir -p /srv/docker/calibre/config
sudo mkdir -p /srv/docker/books
sudo chown -R 1000:1000 /srv/docker/calibre
sudo chown -R 1000:1000 /srv/docker/books

# 2. Remove Kavita and Stacks stacks (from manager)
docker stack rm kavita stacks

# 3. Deploy Calibre-Web Automated stack
cd ~/homelab
docker stack deploy -c stacks/calibre-stack/docker-compose.yml calibre

# 4. Verify deployment
docker service ps calibre_calibre
docker service logs -f calibre_calibre
```

## Configuration

### First Launch

1. Access http://192.168.31.208:8083
2. Default login: `admin` / `admin123`
3. Click **"Basic Configuration"** → **"Feature Configuration"**
4. Enable **"Automated Download"**
5. Configure Anna's Archive settings (add donation key for faster downloads)

### Searching & Downloading

1. Click **"Download Books"** in the menu
2. Search by title, author, or ISBN
3. Select source (Anna's Archive, LibGen, etc.)
4. Click **"Download"** - book is added to library automatically

### Existing Books

Books already in `/srv/docker/books` will be auto-imported:
1. Go to **"Admin"** → **"Configuration"** → **"Edit Metadata"**
2. Click **"Import from Folder"**
3. Select `/books` and click **"Import"**

## Anna's Archive Integration

### For Better Performance (Optional)

If you have an Anna's Archive donation key:
1. Go to **"Download Books"** → **"Settings"**
2. Add your donation key in **"Anna's Archive Key"**
3. This enables faster, more reliable downloads

### Without Donation Key

- Still works, but uses slower mirrors
- May encounter Cloudflare challenges (auto-bypassed)

## Mobile Access

Calibre-Web supports OPDS - add to your mobile e-reader app:
- URL: `http://192.168.31.208:8083/opds`
- Supports: Chunky Ebook Reader, KyBook 3, Marvin, etc.

## Tips

- Change default password immediately
- Books are stored in `/srv/docker/books/`
- Database is in `/srv/docker/calibre/config/`
- Use OPDS for mobile reading
- Supports EPUB, PDF, MOBI, AZW3, CBZ, CBR
