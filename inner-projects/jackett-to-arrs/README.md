# Jackett to Arrs

Sync all configured Jackett indexers to Sonarr and Radarr automatically via API.

## Features

- ✅ Reads all configured indexers directly from Jackett
- ✅ Skips indexers that already exist
- ✅ Only adds indexers that support the respective categories (TV/Movies)
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
   JACKETT_API_KEY=your_jackett_api_key_here

   SONARR_URL=http://192.168.31.75:8989
   SONARR_API_KEY=your_sonarr_api_key_here

   RADARR_URL=http://192.168.31.75:7878
   RADARR_API_KEY=your_radarr_api_key_here
   ```

## Getting API Keys

- **Sonarr:** Settings → General → API Key
- **Radarr:** Settings → General → API Key
- **Jackett:** Settings → API (optional for local access)

## Usage

```bash
cd inner-projects/jackett-to-arrs

# Run normally
bun run add-indexers

# Test run (doesn't actually add)
DRY_RUN=true bun run add-indexers
```

## How It Works

1. Fetches all configured indexers from Jackett (`/api/v2.0/indexers?configured=true`)
2. Checks which indexers already exist in Sonarr/Radarr
3. Adds missing indexers automatically:
   - Sonarr: Only adds indexers that support TV categories (8000, 8010, 8020, 8030)
   - Radarr: Only adds indexers that support Movie categories (2000-2080)
4. Skips semi-private and private indexers by default

## Configuration

All configuration is done via environment variables in `.env`:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `JACKETT_URL` | No | `http://192.168.31.75:9117` | Jackett URL |
| `JACKETT_API_KEY` | No | - | Jackett API key (optional for local) |
| `SONARR_URL` | No | `http://192.168.31.75:8989` | Sonarr URL |
| `SONARR_API_KEY` | Yes | - | Sonarr API key |
| `RADARR_URL` | No | `http://192.168.31.75:7878` | Radarr URL |
| `RADARR_API_KEY` | Yes | - | Radarr API key |
| `DRY_RUN` | No | `false` | Test without adding |

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

## Example Output

```
🎬 Syncing Jackett indexers to Sonarr and Radarr...

📡 Fetching indexers from Jackett...
   Found 12 configured indexers

📦 Processing: TorrentDay (torrentday)
  ✅ Added "TorrentDay" to Sonarr
  ✅ Added "TorrentDay" to Radarr

📦 Processing: IPTorrents (iptorrents)
  ⏭️  Already in Sonarr, skipping...
  ⏭️  Already in Radarr, skipping...

...

✨ Done!
   Sonarr: 5 new indexers added
   Radarr: 7 new indexers added
```

## Tips

- Run the script anytime you add new indexers in Jackett
- Safe to run multiple times - skips existing indexers
- Use `DRY_RUN=true` to test before actually adding
- The `.env` file is git-ignored for security
