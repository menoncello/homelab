# Jackett to Arrs

Add Jackett indexers to Sonarr and Radarr automatically via API.

## Features

- ✅ Adds indexers to Sonarr and Radarr via Torznab
- ✅ Skips indexers that already exist
- ✅ Adds appropriate categories for TV (Sonarr) and Movies (Radarr)
- ✅ Dry run mode for testing
- ✅ Environment variables via `.env` file
- ✅ No Jackett admin API access required

## Setup

1. **Install Bun (if needed):**
   ```bash
   curl -fsSL https://bun.sh/install.sh | bash
   ```

2. **Install dependencies:**
   ```bash
   bun install
   ```

3. **Create `.env` file:**
   ```bash
   cp .env.example .env
   ```

4. **Edit `.env` and add your API keys and indexer list:**
   ```env
   JACKETT_URL=http://192.168.31.75:9117
   INDEXER_LIST=torrentday:TorrentDay,iptorrents:IPTorrents,limetorrents:LimeTorrents

   SONARR_URL=http://192.168.31.75:8989
   SONARR_API_KEY=your_sonarr_api_key_here

   RADARR_URL=http://192.168.31.75:7878
   RADARR_API_KEY=your_radarr_api_key_here
   ```

## Getting API Keys

- **Sonarr:** Settings → General → API Key
- **Radarr:** Settings → General → API Key

## Finding Indexer IDs

To find your Jackett indexer IDs:

1. Open Jackett web UI
2. Click on an indexer
3. Look at the URL: `http://jackett-url/UI/Dashboard#indexer=xyz`
4. The `xyz` part is your indexer ID

For example, if the URL is `http://192.168.31.75:9117/UI/Dashboard#indexer=torrentday`, then:
- Indexer ID: `torrentday`
- Display Name: `TorrentDay` (or any name you prefer)

## Usage

```bash
cd inner-projects/jackett-to-arrs

# Run normally
bun run add-indexers

# Test run (doesn't actually add)
DRY_RUN=true bun run add-indexers
```

## How It Works

1. Reads indexer list from `INDEXER_LIST` environment variable
2. Checks which indexers already exist in Sonarr/Radarr
3. Adds missing indexers automatically using Jackett's Torznab endpoint:
   - Sonarr: Adds with TV categories (8000, 8010, 8020, 8030)
   - Radarr: Adds with Movie categories (2000-2080)

## Configuration

All configuration is done via environment variables in `.env`:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `JACKETT_URL` | No | `http://192.168.31.75:9117` | Jackett URL |
| `INDEXER_LIST` | Yes | - | Comma-separated `id:Name` pairs |
| `SONARR_URL` | No | `http://192.168.31.75:8989` | Sonarr URL |
| `SONARR_API_KEY` | Yes | - | Sonarr API key |
| `RADARR_URL` | No | `http://192.168.31.75:7878` | Radarr URL |
| `RADARR_API_KEY` | Yes | - | Radarr API key |
| `DRY_RUN` | No | `false` | Test without adding |

### INDEXER_LIST Format

```
INDEXER_LIST=id1:Display Name 1,id2:Display Name 2,id3:Display Name 3
```

Examples:
- Single indexer: `INDEXER_LIST=torrentday:TorrentDay`
- Multiple indexers: `INDEXER_LIST=torrentday:TorrentDay,iptorrents:IPTorrents,limetorrents:LimeTorrents`
- ID only (name same as ID): `INDEXER_LIST=torrentday,iptorrents`

## Category IDs

**Sonarr (TV):**
- 8000: TV Other
- 8010: TV SD
- 8020: TV HD
- 8030: TV UHD

**Radarr (Movies):**
- 2000: Movies Other
- 2010: Movies SD
- 2020: Movies HD
- 2030: Movies 3D
- 2040: Movies Bluray
- 2050: Movies UHD
- 2060: Movies DVD
- 2070: Movies WEB-DL
- 2080: Movies Foreign

## Example Output

```
🎬 Syncing Jackett indexers to Sonarr and Radarr...

📡 Found 3 indexers to process

📦 Processing: TorrentDay (torrentday)
  ✅ Added "TorrentDay" to Sonarr
  ✅ Added "TorrentDay" to Radarr

📦 Processing: IPTorrents (iptorrents)
  ⏭️  Already in Sonarr, skipping...
  ⏭️  Already in Radarr, skipping...

📦 Processing: LimeTorrents (limetorrents)
  ✅ Added "LimeTorrents" to Sonarr
  ✅ Added "LimeTorrents" to Radarr

✨ Done!
   Sonarr: 2 new indexers added
   Radarr: 2 new indexers added
```

## Tips

- Run the script anytime you add new indexers in Jackett
- Safe to run multiple times - skips existing indexers
- Use `DRY_RUN=true` to test before actually adding
- The `.env` file is git-ignored for security
- You don't need Jackett admin API access or API keys
