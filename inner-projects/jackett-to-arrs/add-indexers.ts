#!/usr/bin/env bun
/**
 * Add Jackett indexers to Sonarr and Radarr via API
 *
 * Usage: bun add-indexers.ts
 *
 * Automatically reads all configured indexers from Jackett
 * and adds them to Sonarr and Radarr.
 */

const CONFIG = {
  jackett: {
    url: "http://192.168.31.75:9117",
  },
  sonarr: {
    url: "http://192.168.31.75:8989",
    apiKey: "b13994d5951647e387a696bb392c1166",
  },
  radarr: {
    url: "http://192.168.31.75:7878",
    apiKey: "7d84f5f3ac3445978ea8b16faf9f1ae9",
  },
  // Set to true to test without actually adding
  dryRun: false,
};

interface JackettIndexer {
  id: string;
  name: string;
  type: string;
  link: string;
  caps: {
    categories: Array<{ id: number; name: string }>;
  };
}

interface Service {
  url: string;
  apiKey: string;
  name: string;
}

interface Indexer {
  name: string;
  implementation: string;
  configContract: string;
  fields: Array<{ name: string; value: string | number | boolean }>;
}

async function getJackettIndexers(): Promise<JackettIndexer[]> {
  const url = `${CONFIG.jackett.url}/api/v2.0/indexers?configured=true`;

  try {
    const response = await fetch(url, {
      headers: {
        "X-Api-Key": "YOUR_JACKETT_API_KEY", // Jackett usually doesn't require API key for local
      },
    });

    if (!response.ok) {
      throw new Error(`Jackett API error: ${response.status}`);
    }

    const data = await response.json();
    // Filter out Jackett built-in indexers (indexers that start with the indexer name)
    return Object.values(data)
      .filter((i: any) => i.type !== "semi-private" && i.type !== "private")
      .filter((i: any) => !i.id.includes("zetorrents")) // Example: skip specific indexers
      .map((i: any) => ({
        id: i.id,
        name: i.name,
        type: i.type,
        link: i.link,
        caps: i.caps,
      }));
  } catch (error) {
    console.error("❌ Error fetching Jackett indexers:", error);
    return [];
  }
}

async function addIndexer(
  service: Service,
  indexer: JackettIndexer,
  categories: string
): Promise<boolean> {
  const url = `${service.url}/api/v3/indexer`;

  // Get the Torznab URL from Jackett
  // Format: http://jackett:9117/api/{indexer_id}?passkey=xxx
  const baseUrl = `${CONFIG.jackett.url}/api/${indexer.id}`;

  const payload: Indexer = {
    name: indexer.name,
    implementation: "Torznab",
    configContract: "TorznabSettings",
    fields: [
      { name: "baseUrl", value: baseUrl },
      { name: "apiPath", value: "" }, // Empty for Jackett
      { name: "apiKey", value: "" },
      { name: "categories", value: categories },
      { name: "automaticSearch", value: true },
      { name: "interactiveSearch", value: true },
      { name: "priority", value: 1 }, // Lower = higher priority
      { name: "downloadClientId", value: "" },
    ],
    enable: true,
  };

  if (CONFIG.dryRun) {
    console.log(`  🧪 [DRY RUN] Would add "${indexer.name}" to ${service.name}`);
    console.log(`     Base URL: ${baseUrl}`);
    return true;
  }

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "X-Api-Key": service.apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error(`  ❌ Error adding to ${service.name}: ${error}`);
      return false;
    }

    console.log(`  ✅ Added "${indexer.name}" to ${service.name}`);
    return true;
  } catch (error) {
    console.error(`  ❌ Error adding to ${service.name}:`, error);
    return false;
  }
}

async function getExistingIndexers(service: Service): Promise<any[]> {
  try {
    const response = await fetch(`${service.url}/api/v3/indexer`, {
      headers: {
        "X-Api-Key": service.apiKey,
      },
    });

    if (!response.ok) {
      return [];
    }

    return await response.json();
  } catch {
    return [];
  }
}

function indexerSupportsCategory(indexer: JackettIndexer, categoryIds: number[]): boolean {
  if (!indexer.caps?.categories) return false;
  const indexerCatIds = indexer.caps.categories.map((c) => c.id);
  return categoryIds.some((id) => indexerCatIds.includes(id));
}

async function main() {
  console.log("🎬 Syncing Jackett indexers to Sonarr and Radarr...\n");

  // Get Jackett indexers
  console.log("📡 Fetching indexers from Jackett...");
  const jackettIndexers = await getJackettIndexers();

  if (jackettIndexers.length === 0) {
    console.error("❌ No indexers found in Jackett!");
    process.exit(1);
  }

  console.log(`   Found ${jackettIndexers.length} configured indexers\n`);

  // Get existing indexers to avoid duplicates
  const sonarrIndexers = await getExistingIndexers(CONFIG.sonarr);
  const radarrIndexers = await getExistingIndexers(CONFIG.radarr);

  const sonarrNames = new Set(sonarrIndexers.map((i) => i.name));
  const radarrNames = new Set(radarrIndexers.map((i) => i.name));

  // Category IDs
  const tvCategories = [8000, 8010, 8020, 8030]; // TV
  const movieCategories = [2000, 2010, 2020, 2030, 2040, 2050, 2060, 2070, 2080]; // Movies

  let addedToSonarr = 0;
  let addedToRadarr = 0;

  for (const indexer of jackettIndexers) {
    console.log(`\n📦 Processing: ${indexer.name} (${indexer.id})`);

    // Sonarr (TV)
    const sonarrExists = sonarrNames.has(indexer.name);
    if (sonarrExists) {
      console.log(`  ⏭️  Already in Sonarr, skipping...`);
    } else if (!indexerSupportsCategory(indexer, tvCategories)) {
      console.log(`  ⏭️  Doesn't support TV categories, skipping Sonarr...`);
    } else {
      const added = await addIndexer(
        { ...CONFIG.sonarr, name: "Sonarr" },
        indexer,
        tvCategories.join(",")
      );
      if (added) addedToSonarr++;
    }

    // Radarr (Movies)
    const radarrExists = radarrNames.has(indexer.name);
    if (radarrExists) {
      console.log(`  ⏭️  Already in Radarr, skipping...`);
    } else if (!indexerSupportsCategory(indexer, movieCategories)) {
      console.log(`  ⏭️  Doesn't support Movie categories, skipping Radarr...`);
    } else {
      const added = await addIndexer(
        { ...CONFIG.radarr, name: "Radarr" },
        indexer,
        movieCategories.join(",")
      );
      if (added) addedToRadarr++;
    }
  }

  console.log(`\n✨ Done!`);
  console.log(`   Sonarr: ${addedToSonarr} new indexers added`);
  console.log(`   Radarr: ${addedToRadarr} new indexers added`);
}

main().catch((error) => {
  console.error("Error:", error);
  process.exit(1);
});
