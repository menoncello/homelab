# Stacks Stack

Stacks is a lightweight download manager for Anna's Archive (books, comics, magazines). It provides a web interface to queue, manage, and download books automatically.

## Access

- **URL:** http://192.168.31.6:7788
- **Default credentials:**
  - Username: `admin`
  - Password: `admin123` (change after first login!)

## Features

- **Queue Management** - Add books from your browser with one click
- **Fast Download Support** - Use Anna's Archive membership for priority downloads
- **Automatic Fallback** - Seamlessly falls back to mirror sites
- **Real-time Dashboard** - Monitor downloads, queue status, and history
- **Tampermonkey Script** - Adds download buttons directly to Anna's Archive

## First Time Setup

```bash
# 1. Create volume directories (on Xeon01)
ssh eduardo@192.168.31.6
sudo mkdir -p /srv/docker/stacks/{config,logs}
sudo mkdir -p /srv/docker/books
sudo chown -R 1000:1000 /srv/docker/stacks
sudo chown -R 1000:1000 /srv/docker/books

# 2. Deploy stack (from manager)
cd ~/homelab/stacks/stacks-stack
docker stack deploy -c media.docker-compose.yml stacks

# 3. Verify deployment
docker service ps stacks_stacks
docker service logs -f stacks_stacks
```

## Configuration

After first launch:

1. **Settings tab** → Change default password (`admin123`)
2. **Copy API key** for Tampermonkey script
3. **Configure Anna's Archive key** (if you have membership)
4. **Adjust download delays and retry settings**

## Tampermonkey Script

1. Install Tampermonkey browser extension
2. Add script from Stacks Settings tab
3. Visit Anna's Archive → download buttons appear
4. Click download → book added to Stacks queue

## Integration with Kavita

Stacks downloads to `/srv/docker/books` - the same folder Kavita reads from!

1. Download book via Stacks
2. Book appears in `/srv/docker/books/`
3. Kavita scans folder automatically
4. Book appears in your Kavita library

## FlareSolverr

FlareSolverr is included to bypass Cloudflare/DDoS-Guard protection on mirror sites:
- Access: http://192.168.31.6:8191
- Automatically configured in Stacks
- Required for reliable mirror downloads

## Tips

- Change default password immediately after first login
- Don't expose to internet without VPN/reverse proxy
- Download queue is persistent across restarts
