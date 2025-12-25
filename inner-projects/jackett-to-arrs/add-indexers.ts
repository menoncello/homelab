#!/usr/bin/env bun
/**
 * Add Jackett indexers to Sonarr and Radarr via API
 *
 * Usage: bun add-indexers.ts
 *
 * Uses Puppeteer to get Jackett session cookies, then fetches
 * all configured indexers and adds them to Sonarr and Radarr.
 */

// Load environment variables from .env
import { config } from "dotenv";
import puppeteer from "puppeteer";

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
  enable?: boolean;
  priority?: number;
}

/**
 * Get Jackett session cookies using Puppeteer
 */
async function getJackettCookies(): Promise<string> {
  console.log("🔐 Connecting to Jackett web UI to get session cookies...");

  const browser = await puppeteer.launch({
    headless: true,
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
  });

  try {
    const page = await browser.newPage();
    await page.goto(CONFIG.jackett.url, {
      waitUntil: "networkidle2",
      timeout: 30000,
    });

    // Get cookies after page load
    const cookies = await page.cookies();
    await browser.close();

    // Format cookies for fetch request
    const cookieHeader = cookies
      .map((c) => `${c.name}=${c.value}`)
      .join("; ");

    console.log("   ✅ Got session cookies");
    return cookieHeader;
  } catch (error) {
    await browser.close();
    throw error;
  }
}

/**
 * Fetch all indexers from Jackett using session cookies
 */
async function getJackettIndexers(cookies: string): Promise<JackettIndexer[]> {
  const url = `${CONFIG.jackett.url}/api/v2.0/indexers`;

  try {
    console.log(`   Fetching indexers from: ${url}`);

    const response = await fetch(url, {
      headers: {
        "Cookie": cookies,
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Jackett API error: ${response.status} - ${errorText}`);
    }

    const data = await response.json();

    // Filter only configured indexers
    const indexers = Object.values(data)
      .filter((i: any) => i.configured || i.type === "public")
      .filter((i: any) => i.type !== "semi-private" && i.type !== "private")
      .map((i: any) => ({
        id: i.id,
        name: i.name,
        type: i.type,
        link: i.link,
        caps: i.caps,
      }));

    console.log(`   Found ${Object.values(data).length} total indexers`);
    console.log(`   ${indexers.length} configured/public indexers\n`);

    return indexers;
  } catch (error) {
    console.error("❌ Error fetching Jackett indexers:", error);
    return [];
  }
}

async function addIndexer(
  service: Service,
  indexer: JackettIndexer,
  categories: number[]
): Promise<boolean> {
  const url = `${service.url}/api/v3/indexer`;

  // Torznab URL from Jackett
  const baseUrl = `${CONFIG.jackett.url}/api/${indexer.id}`;

  const payload: Indexer = {
    name: indexer.name,
    implementation: "Torznab",
    configContract: "TorznabSettings",
    priority: 25,
    fields: [
      { name: "baseUrl", value: baseUrl },
      { name: "apiPath", value: "" },
      { name: "apiKey", value: "" },
      { name: "categories", value: categories.join(",") },
      { name: "automaticSearch", value: true },
      { name: "interactiveSearch", value: true },
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

function indexerSupportsCategory(indexer: JackettIndexer, categoryIds: number[]): boolean {
  if (!indexer.caps?.categories) return true; // Assume yes if no caps
  const indexerCatIds = indexer.caps.categories.map((c) => c.id);
  return categoryIds.some((id) => indexerCatIds.includes(id));
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

  // Get Jackett session cookies
  const cookies = await getJackettCookies();

  // Get Jackett indexers
  console.log("📡 Fetching indexers from Jackett...");
  const jackettIndexers = await getJackettIndexers(cookies);

  if (jackettIndexers.length === 0) {
    console.error("❌ No indexers found in Jackett!");
    process.exit(1);
  }

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
        tvCategories
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
