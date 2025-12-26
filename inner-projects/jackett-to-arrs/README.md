# Jackett to Arrs

Sync all configured Jackett indexers to Sonarr, Radarr, and Listenarr automatically via API.

## Features

- ✅ Automatically reads all configured indexers from Jackett (using Puppeteer)
- ✅ Skips indexers that already exist
- ✅ Only adds indexers that support the respective categories (TV/Movies/Books)
- ✅ Dry run mode for testing
- ✅ Environment variables via `.env` file
- ✅ No manual configuration needed

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

4. **Edit `.env` and add your API keys:**
   ```env
   JACKETT_URL=http://192.168.31.75:9117
   SONARR_URL=http://192.168.31.75:8989
   SONARR_API_KEY=your_sonarr_api_key_here
   RADARR_URL=http://192.168.31.75:7878
   RADARR_API_KEY=your_radarr_api_key_here
   LISTENARR_URL=http://192.168.31.75:8988
   LISTENARR_API_KEY=your_listenarr_api_key_here
   ```

## Getting API Keys

- **Sonarr:** Settings → General → API Key
- **Radarr:** Settings → General → API Key
- **Listenarr:** Settings → General → API Key

## Usage

```bash
cd inner-projects/jackett-to-arrs

# Run normally
bun run add-indexers

# Test run (doesn't actually add)
DRY_RUN=true bun run add-indexers
```

## How It Works

1. Uses Puppeteer to open Jackett web UI and get session cookies
2. Fetches all configured indexers from Jackett API using the cookies
3. Checks which indexers already exist in Sonarr/Radarr/Listenarr
4. Adds missing indexers automatically:
   - Sonarr: Only adds indexers that support TV categories (8000, 8010, 8020, 8030)
   - Radarr: Only adds indexers that support Movie categories (2000-2080)
   - Listenarr: Only adds indexers that support Book categories (8000-8050)
5. Skips semi-private and private indexers by default

## Configuration

All configuration is done via environment variables in `.env`:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `JACKETT_URL` | No | `http://192.168.31.75:9117` | Jackett URL |
| `SONARR_URL` | No | `http://192.168.31.75:8989` | Sonarr URL |
| `SONARR_API_KEY` | No* | - | Sonarr API key |
| `RADARR_URL` | No | `http://192.168.31.75:7878` | Radarr URL |
| `RADARR_API_KEY` | No* | - | Radarr API key |
| `LISTENARR_URL` | No | `http://192.168.31.75:8988` | Listenarr URL |
| `LISTENARR_API_KEY` | No* | - | Listenarr API key |
| `DRY_RUN` | No | `false` | Test without adding |

*At least one service API key is required (Sonarr, Radarr, or Listenarr)

## Filtering Indexers

The script includes filters to skip certain indexer types. Modify `getJackettIndexers()` in `add-indexers.ts`:

```typescript
.filter((i: any) => i.type !== "semi-private")  // Skip semi-private
.filter((i: any) => !i.id.includes("zetorrents"))  // Skip specific indexer
```

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

**Listenarr (Books & Audiobooks):**
- 8000: Books Other
- 8010: Books Mags
- 8020: Books EBooks
- 8030: Books Comics
- 8040: Books Audio
- 8050: Books Other

## Example Output

```
🎬 Syncing Jackett indexers to Sonarr, Radarr, and Listenarr...

🔐 Connecting to Jackett web UI to get session cookies...
   ✅ Got session cookies

📡 Fetching indexers from Jackett...
   Found 50 total indexers
   12 configured/public indexers

📦 Processing: TorrentDay (torrentday)
  ✅ Added "TorrentDay" to Sonarr
  ✅ Added "TorrentDay" to Radarr
  ✅ Added "TorrentDay" to Listenarr

📦 Processing: IPTorrents (iptorrents)
  ⏭️  Already in Sonarr, skipping...
  ⏭️  Already in Radarr, skipping...
  ⏭️  Already in Listenarr, skipping...

...

✨ Done!
   Sonarr: 5 new indexers added
   Radarr: 7 new indexers added
   Listenarr: 4 new indexers added
```

## Tips

- Run the script anytime you add new indexers in Jackett
- Safe to run multiple times - skips existing indexers
- Use `DRY_RUN=true` to test before actually adding
- The `.env` file is git-ignored for security
- Puppeteer runs in headless mode (no UI)
