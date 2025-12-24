# Calibre-Web Stack

Calibre-Web is a web app providing a clean interface for browsing, reading and downloading eBooks stored in a Calibre database.

## Access

- **URL:** http://192.168.31.208:8083
- **Default credentials:**
  - Username: `admin`
  - Password: `admin123` (change after first login)

## Features

- **Browse** - Browse your Calibre library by cover, list, or grid view
- **Read** - Read eBooks in the browser (EPUB, PDF, TXT)
- **Download** - Download eBooks in any format
- **Upload** - Upload new eBooks to the library
- **Edit Metadata** - Edit title, author, cover, etc.
- **OPDS** - Access from mobile e-reader apps
- **Auto-import** - Automatically imports books from Stacks downloads

## First Time Setup

```bash
# 1. Create volume directories (on Xeon01)
ssh eduardo@192.168.31.208
sudo mkdir -p /srv/docker/calibre/config
sudo mkdir -p /srv/docker/books
sudo chown -R 1000:1000 /srv/docker/calibre
sudo chown -R 1000:1000 /srv/docker/books

# 2. Remove Kavita stack (from manager)
docker stack rm kavita

# 3. Deploy Calibre-Web stack
cd ~/homelab
docker stack deploy -c stacks/calibre-stack/docker-compose.yml calibre

# 4. Verify deployment
docker service ps calibre_calibre
docker service logs -f calibre_calibre
```

## Configuration

### First Launch

1. Access http://192.168.31.208:8083
2. Click "Obstacle Course" to set admin password
3. Specify Calibre settings (database location)
4. Set `Path to Books` to `/books`

### Adding Books from Stacks

Books downloaded by Stacks appear in `/books` automatically:
1. Click **Add Books** → **Import from Folder**
2. Select `/books`
3. Books are automatically detected and added to library

### Auto-Import

The `calibre-web-automated` mod automatically:
- Scans `/books` for new files
- Imports them to the Calibre database
- Downloads metadata and covers

## Integration with Stacks

Stacks downloads to `/srv/docker/books` - Calibre-Web reads from the same folder!

1. Download book via Stacks
2. Book appears in `/srv/docker/books/`
3. Calibre-Web auto-imports on next scan
4. Book appears in your library

## Mobile Access

Calibre-Web supports OPDS - add to your mobile e-reader app:
- URL: `http://192.168.31.208:8083/opds`
- Supports: Chunky Ebook Reader, KyBook 3, Marvin, etc.

## Tips

- Change default password immediately
- Enable "Enable Upload" in settings to add books
- Use OPDS for mobile reading
- Calibre-Web can convert formats on-the-fly
