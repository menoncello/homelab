# Jackett to Arrs

Sync all configured Jackett indexers to Sonarr and Radarr automatically via API.

## Features

- ✅ Reads all configured indexers directly from Jackett
- ✅ Skips indexers that already exist
- ✅ Only adds indexers that support the respective categories (TV/Movies)
- ✅ Dry run mode for testing
- ✅ No manual configuration needed

## Setup

1. **Get API keys:**
   - Sonarr: Settings → General → API Key
   - Radarr: Settings → General → API Key

2. **Configure the script:**
   Edit `add-indexers.ts` and update the API keys (lines 17, 21).

3. **Install Bun (if needed):**
   ```bash
   curl -fsSL https://bun.sh/install.sh | bash
   ```

## Usage

```bash
cd inner-projects/jackett-to-arrs

# Test run (doesn't actually add)
bun add-indexers.ts  # with dryRun: false

# Or enable dryRun in CONFIG first to test
```

## How It Works

1. Fetches all configured indexers from Jackett (`/api/v2.0/indexers?configured=true`)
2. Checks which indexers already exist in Sonarr/Radarr
3. Adds missing indexers automatically:
   - Sonarr: Only adds indexers that support TV categories (8000, 8010, 8020, 8030)
   - Radarr: Only adds indexers that support Movie categories (2000-2080)
4. Skips semi-private and private indexers by default

## Configuration

Edit the `CONFIG` object in `add-indexers.ts`:

```typescript
const CONFIG = {
  jackett: {
    url: "http://192.168.31.75:9117",  // Jackett URL
  },
  sonarr: {
    url: "http://192.168.31.75:8989",    // Sonarr URL
    apiKey: "YOUR_SONARR_API_KEY",
  },
  radarr: {
    url: "http://192.168.31.75:7878",    // Radarr URL
    apiKey: "YOUR_RADARR_API_KEY",
  },
  dryRun: false,  // Set true to test without adding
};
```

## Filtering Indexers

The script includes filters to skip certain indexer types. You can modify these in `getJackettIndexers()`:

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
- Use `dryRun: true` first to see what would be added
