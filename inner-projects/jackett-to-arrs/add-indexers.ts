#!/usr/bin/env bun
/**
 * Add indexers to Sonarr and Radarr via API
 *
 * Usage: bun add-indexers.ts
 *
 * Configure your indexers and API keys below
 */

const CONFIG = {
  sonarr: {
    url: "http://192.168.31.75:8989",
    apiKey: "YOUR_SONARR_API_KEY", // Settings -> General -> API Key
  },
  radarr: {
    url: "http://192.168.31.75:7878",
    apiKey: "YOUR_RADARR_API_KEY", // Settings -> General -> API Key
  },
};

// Add your indexers here
const indexers = [
  {
    name: " indexer1",
    implementation: "Torznab",
    configContract: "TorznabSettings",
    fields: [
      { name: "baseUrl", value: "http://jackett:9117/YOUR_INDEXER" },
      { name: "apiPath", value: "/api" },
      { name: "categories", value: "8000,8010" }, // Sonarr categories
      { name: "automaticSearch", value: true },
      { name: "interactiveSearch", value: true },
      { name: "priority", value: 1 },
    ],
  },
  // Add more indexers as needed
  // {
  //   name: " indexer2",
  //   implementation: "Torznab",
  //   configContract: "TorznabSettings",
  //   fields: [...],
  // },
];

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
  enable?: boolean;
}

async function addIndexer(service: Service, indexer: Indexer, categories?: string): Promise<void> {
  const url = `${service.url}/api/v3/indexer`;

  // Adjust categories for Radarr
  const fields = categories
    ? indexer.fields.map((f) =>
        f.name === "categories" ? { ...f, value: categories } : f
      )
    : indexer.fields;

  const payload = {
    name: indexer.name,
    implementation: indexer.implementation,
    configContract: indexer.configContract,
    fields: fields,
    enable: true,
  };

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
      return;
    }

    console.log(`  ✅ Added "${indexer.name}" to ${service.name}`);
  } catch (error) {
    console.error(`  ❌ Error adding to ${service.name}:`, error);
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

async function main() {
  console.log("🎬 Adding indexers to Sonarr and Radarr...\n");

  // Check API keys
  if (CONFIG.sonarr.apiKey === "YOUR_SONARR_API_KEY") {
    console.error("❌ Please configure your API keys in the script!");
    console.log("   Sonarr: Settings -> General -> API Key");
    console.log("   Radarr: Settings -> General -> API Key");
    process.exit(1);
  }

  // Get existing indexers
  const sonarrIndexers = await getExistingIndexers(CONFIG.sonarr);
  const radarrIndexers = await getExistingIndexers(CONFIG.radarr);

  for (const indexer of indexers) {
    console.log(`\n📦 Processing: ${indexer.name}`);

    // Check if already exists in Sonarr
    const sonarrExists = sonarrIndexers.some((i) => i.name === indexer.name);
    if (sonarrExists) {
      console.log(`  ⏭️  Already in Sonarr, skipping...`);
    } else {
      await addIndexer(
        { ...CONFIG.sonarr, name: "Sonarr" },
        indexer,
        "8000,8010" // TV categories
      );
    }

    // Check if already exists in Radarr
    const radarrExists = radarrIndexers.some((i) => i.name === indexer.name);
    if (radarrExists) {
      console.log(`  ⏭️  Already in Radarr, skipping...`);
    } else {
      await addIndexer(
        { ...CONFIG.radarr, name: "Radarr" },
        indexer,
        "2000,2010,2020,2030,2040,2050,2060,2070,2080" // Movie categories
      );
    }
  }

  console.log("\n✨ Done!");
}

main().catch((error) => {
  console.error("Error:", error);
  process.exit(1);
});
