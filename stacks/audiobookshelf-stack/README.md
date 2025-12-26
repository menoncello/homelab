# Audiobookshelf Stack

Self-hosted audiobook and podcast server with a clean, modern interface.

## Features

- ✅ Beautiful web interface for browsing and playing audiobooks
- ✅ Multi-user support with permissions and progress tracking
- ✅ Automatic metadata fetching from various sources
- ✅ Podcast support with RSS feed integration
- ✅ Mobile apps (Booksonic / Audiobookshelf apps)
- ✅ Chapter support and bookmarks
- ✅ Series and collections
- ✅ Batch processing tools
- ✅ eBook library support

## Quick Start

```bash
cd stacks/audiobookshelf-stack
docker stack deploy -c docker-compose.yml audiobookshelf
```

## Access

- **Web UI:** http://192.168.31.237:8080
- **Port:** 8080 (internal: 80)

## First Time Setup

1. Open the web UI at http://192.168.31.237:8080
2. Create your admin account
3. Add your audiobook library path
4. Optionally add podcast feeds

## Configuration

### Libraries

After setup, add your libraries:
- **Audiobooks:** `/audiobooks` - mapped to `/media/audiobooks`
- **Podcasts:** `/podcasts` - mapped to `/media/podcasts`

### Users

Go to **Settings → Users** to create additional users with permissions:
- Can restrict to specific libraries
- Can set parental controls
- Each user has their own progress tracking

### Metadata

Audiobookshelf automatically fetches metadata from:
- Audible
- iTunes
- Google Books
- Audiobooks.com

### Mobile Apps

Use the **Audiobookshelf** or **Booksonic** app:
- Server URL: `http://192.168.31.237:8080`
- Enter your username and password

## Volume Structure

| Volume | Path | Purpose |
|--------|------|---------|
| `audiobookshelf-config` | /data/docker/audiobookshelf/config | Configuration and database |
| `audiobookshelf-metadata` | /data/docker/audiobookshelf/metadata | Cached metadata and covers |
| `audiobookshelf-audiobooks` | /media/audiobooks | Audiobook library |
| `audiobookshelf-podcasts` | /media/podcasts | Podcast downloads |

## Supported Formats

**Audiobooks:**
- MP3, M4A, M4B, FLAC, OPUS, OGG
- Single files or folder-based
- Auto-detects multi-file audiobooks

**Podcasts:**
- RSS feed URLs
- Auto-download new episodes

## Integration with *arr

Audiobookshelf works well with:
- **Listenarr** - For automated audiobook download
- **Readarr** - Alternative for ebooks/audiobooks

Import downloaded books from:
```
/audiobooks/Author Name/Book Name/
```

## Tips

- Folder structure matters: `/audiobooks/Author/Series/Book Name/`
- Use embedded metadata in audio files for best results
- NFO files and cover.jpg are also recognized
- Set up automatic backups in Settings

## Resources

- [Audiobookshelf GitHub](https://github.com/advplyr/audiobookshelf)
- [Documentation](https://audiobookshelf.org/)
- [Discord](https://discord.gg/pJgEYqn8xH)

## Notes

- Lightweight resource usage
- No database required (SQLite built-in)
- Can optionally use PostgreSQL for larger installations
- Regular backups recommended for /config directory
