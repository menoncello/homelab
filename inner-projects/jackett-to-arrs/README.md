# Jackett to Arrs

Add Jackett indexers to Sonarr and Radarr automatically via API.

## Setup

1. **Get API keys:**
   - Sonarr: Settings → General → API Key
   - Radarr: Settings → General → API Key

2. **Configure the script:**
   Edit `add-indexers.ts` and add your API keys and indexers.

3. **Install dependencies (if needed):**
   ```bash
   bun install
   ```

## Usage

```bash
bun run add-indexers.ts
```

## Indexer Configuration

Each indexer needs:
- `name`: Display name
- `implementation`: Usually "Torznab" for Jackett
- `configContract`: Usually "TorznabSettings" for Jackett
- `fields`: Configuration fields
  - `baseUrl`: Your Jackett Torznab URL (e.g., `http://jackett:9117/api`)
  - `categories`: Category IDs (auto-set for Sonarr/Radarr)

### Example Indexers

```typescript
const indexers = [
  {
    name: "TorrentDay",
    implementation: "Torznab",
    configContract: "TorznabSettings",
    fields: [
      { name: "baseUrl", value: "http://jackett:9117/torrentday" },
      { name: "apiPath", value: "/api" },
      { name: "automaticSearch", value: true },
      { name: "interactiveSearch", value: true },
      { name: "priority", value: 1 },
    ],
  },
];
```

### Category IDs

**Sonarr (TV):** `8000,8010`
- 8000: TV Other
- 8010: TV SD
- 8020: TV HD
- 8030: TV UHD

**Radarr (Movies):** `2000,2010,2020,2030,2040,2050,2060,2070,2080`
- 2000: Movies Other
- 2010: Movies SD
- 2020: Movies HD
- 2030: Movies 3D
- 2040: Movies Bluray
- 2050: Movies UHD
- 2060: Movies DVD
- 2070: Movies WEB-DL
- 2080: Movies Foreign

## Getting Jackett URLs

1. Open Jackett: http://192.168.31.75:9117
2. Click "Show Torznab" next to your indexer
3. Copy the URL (e.g., `http://192.168.31.75:9117/torrentday/api?passkey=xxx`)
4. Use base path: `http://jackett:9117/torrentday`

## Tips

- The script skips indexers that already exist
- You can run it multiple times safely
- Indexers are added with `enable: true` by default
