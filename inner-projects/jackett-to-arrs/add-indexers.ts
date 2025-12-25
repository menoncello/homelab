#!/usr/bin/env bun
/**
 * Add Jackett indexers to Sonarr and Radarr via API
 *
 * Usage: bun add-indexers.ts
 *
 * Reads indexer IDs from INDEXER_LIST environment variable
 * and adds them to Sonarr and Radarr using Jackett's Torznab endpoint.
 */

// Load environment variables from .env
import { config } from "dotenv";

config();

const CONFIG = {
  jackett: {
    url: process.env.JACKETT_URL || "http://192.168.31.75:9117",
  },
  sonarr: {
    url: process.env.SONARR_URL || "http://192.168.31.75:8989",
    apiKey: process.env.SONARR_API_KEY || "",
  },
  radarr: {
    url: process.env.RADARR_URL || "http://192.168.31.75:7878",
    apiKey: process.env.RADARR_API_KEY || "",
  },
  // Set to true to test without actually adding
  dryRun: process.env.DRY_RUN === "true",
};

// Parse indexer list from environment (comma-separated: id1:id2:name1,id2:id3:name2,...)
// or use defaults. Format: indexerId:torznabCapsId:displayname
function getIndexerList(): Array<{ id: string; name: string; capsUrl: string }> {
  const envList = process.env.INDEXER_LIST;
  if (envList) {
    return envList.split(",").map((item) => {
      const parts = item.trim().split(":");
      if (parts.length >= 2) {
        return { id: parts[0], name: parts[1] || parts[0], capsUrl: parts[0] };
      }
      return { id: parts[0], name: parts[0], capsUrl: parts[0] };
    });
  }

  // Fallback: return empty and require user to specify
  return [];
}

interface IndexerDef {
  id: string;
  name: string;
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
  enable: boolean;
}

async function addIndexer(
  service: Service,
  indexer: IndexerDef,
  categories: number[]
): Promise<boolean> {
  const url = `${service.url}/api/v3/indexer`;

  // Torznab URL from Jackett
  const baseUrl = `${CONFIG.jackett.url}/api/${indexer.id}`;

  const payload: Indexer = {
    name: indexer.name,
    implementation: "Torznab",
    configContract: "TorznabSettings",
    fields: [
      { name: "baseUrl", value: baseUrl },
      { name: "apiPath", value: "" },
      { name: "apiKey", value: "" },
      { name: "categories", value: categories.join(",") },
      { name: "automaticSearch", value: true },
      { name: "interactiveSearch", value: true },
      { name: "priority", value: 1 },
      { name: "downloadClientId", value: "" },
    ],
    enable: true,
  };

  if (CONFIG.dryRun) {
    console.log(`  🧪 [DRY RUN] Would add "${indexer.name}" to ${service.name}`);
    console.log(`     Base URL: ${baseUrl}`);
    console.log(`     Categories: ${categories.join(",")}`);
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

async function main() {
  console.log("🎬 Syncing Jackett indexers to Sonarr and Radarr...\n");

  // Validate API keys
  if (!CONFIG.sonarr.apiKey || !CONFIG.radarr.apiKey) {
    console.error("❌ Missing API keys! Please set them in .env file:");
    console.error("   SONARR_API_KEY=xxx");
    console.error("   RADARR_API_KEY=xxx");
    process.exit(1);
  }

  // Get indexer list from environment
  const indexers = getIndexerList();

  if (indexers.length === 0) {
    console.error("❌ No indexers configured!");
    console.error("");
    console.error("To use this script, add your Jackett indexer IDs to .env:");
    console.error("");
    console.error("  INDEXER_LIST=indexer-id-1:Display Name 1,indexer-id-2:Display Name 2,...");
    console.error("");
    console.error("To find your indexer IDs:");
    console.error("  1. Open Jackett web UI");
    console.error("  2. Click on an indexer");
    console.error("  3. The URL shows the indexer ID (e.g., /UI/Dashboard#indexer=torrentday)");
    console.error("  4. Use 'torrentday' as the ID");
    console.error("");
    console.error("Example:");
    console.error("  INDEXER_LIST=torrentday:TorrentDay,iptorrents:IPTorrents,limetorrents:LimeTorrents");
    process.exit(1);
  }

  console.log(`📡 Found ${indexers.length} indexers to process\n`);

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

  for (const indexer of indexers) {
    console.log(`\n📦 Processing: ${indexer.name} (${indexer.id})`);

    // Sonarr (TV)
    const sonarrExists = sonarrNames.has(indexer.name);
    if (sonarrExists) {
      console.log(`  ⏭️  Already in Sonarr, skipping...`);
    } else {
      const added = await addIndexer(
        { ...CONFIG.sonarr, name: "Sonarr" },
        indexer,
        tvCategories
      );
      if (added) addedToSonarr++;
    }

    // Radarr (Movies)
    const radarrExists = radarrNames.has(indexer.name);
    if (radarrExists) {
      console.log(`  ⏭️  Already in Radarr, skipping...`);
    } else {
      const added = await addIndexer(
        { ...CONFIG.radarr, name: "Radarr" },
        indexer,
        movieCategories
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
