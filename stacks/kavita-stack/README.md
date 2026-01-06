# Kavita Stack

Kavita is a fast, feature-rich, cross platform reading server. Built with the goal of being a full solution for all your reading needs.

## Access

- **URL:** http://192.168.31.5:5000
- **Default credentials:** Create admin account on first launch

## Features

- **EPUB, PDF, Comics, Manga** - Support for multiple formats
- **Built-in Readers** - Single page, double page, scroll, and more
- **Reading Progress** - Tracks your reading position across devices
- **Collections** - Organize your library into collections
- **OPDS Support** - Access your library from mobile apps
- **Dark Mode** - Easy on the eyes
- **Auto-Scan** - Automatically detects new books

## First Time Setup

```bash
# 1. Create volume directories (on Helios/pop-os)
sudo mkdir -p /data/docker/kavita/config
sudo mkdir -p /media/books
sudo chown -R 1000:1000 /data/docker/kavita
sudo chown -R 1000:1000 /media/books

# 2. Deploy stack
cd ~/homelab
docker stack deploy -c stacks/kavita-stack/docker-compose.yml kavita

# 3. Verify deployment
docker service ps kavita_kavita
docker service logs -f kavita_kavita
```

## Configuration

After first launch:

1. **Create admin account**
2. **Add library:**
   - Name: `Books`
   - Path: `/books`
   - Type: `Books`
3. **Scan library:** Kavita will scan and organize your books
4. **Configure users:** Create accounts for family members

## Adding Books

Books can be added to `/media/books` on Helios:
- From Stacks (Anna's Archive download manager)
- Manual upload via SCP/SFTP
- From Calibre library

## Supported Formats

- Ebooks: EPUB, PDF, MOBI, AZW3
- Comics: CBZ, CBR, CB7
- Manga: CBZ, CBR
- Images: PNG, JPG, WEBP

## Tips

- Kavita automatically scans the library folder for new books
- Set up OPDS to access from mobile e-reader apps
- Use collections to organize by genre/author/series
