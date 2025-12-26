#!/usr/bin/env bun
/**
 * Add Jackett indexers to Sonarr, Radarr, and Listenarr via API
 *
 * Usage: bun add-indexers.ts
 *
 * Uses Puppeteer to get Jackett session cookies, then fetches
 * all configured indexers and adds them to Sonarr, Radarr, and Listenarr.
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
  listenarr: {
    url: process.env.LISTENARR_URL || "http://192.168.31.75:8988",
    apiKey: process.env.LISTENARR_API_KEY || "",
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
  requiresCsrf?: boolean;
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
 * Get CSRF token from *arr applications that require it
 * First tries API endpoint, then falls back to Puppeteer for web UI
 */
async function getCsrfToken(service: Service): Promise<{ token: string | null; cookies: string }> {
  // First try to get CSRF from API endpoint (faster)
  try {
    const response = await fetch(`${service.url}/api/v3/indexer/schema`, {
      headers: {
        "X-Api-Key": service.apiKey,
      },
    });

    const csrfFromHeader = response.headers.get("X-CSRF-Token");
    const setCookie = response.headers.get("Set-Cookie");

    if (csrfFromHeader) {
      console.log(`  ✅ Got CSRF token from API header`);
      return { token: csrfFromHeader, cookies: setCookie || "" };
    }
  } catch {
    // Fall through to Puppeteer approach
  }

  // Fallback: Use Puppeteer to access the web UI
  try {
    console.log(`  🔐 Getting CSRF token from ${service.name} web UI...`);

    const browser = await puppeteer.launch({
      headless: true,
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });

    try {
      const page = await browser.newPage();

      // Enable request interception to capture response headers
      await page.setRequestInterception(true);
      let csrfFromHeader: string | null = null;

      page.on('response', (response) => {
        const headers = response.headers();
        // Try different header names
        csrfFromHeader = csrfFromHeader ||
          headers['x-csrf-token'] ||
          headers['x-xsrf-token'] ||
          headers['csrf-token'];
      });

      await page.goto(service.url, {
        waitUntil: "networkidle2",
        timeout: 30000,
      });

      // Get cookies
      const cookies = await page.cookies();
      const cookieHeader = cookies
        .map((c) => `${c.name}=${c.value}`)
        .join("; ");

      // Try to get CSRF token from page
      const csrfToken = await page.evaluate(() => {
        // Check for common CSRF token locations
        const metaTag = document.querySelector('meta[name="csrf-token"]');
        if (metaTag) {
          return metaTag.getAttribute('content');
        }

        // Check for antiForgery token in window
        if ((window as any).antiForgeryToken) {
          return (window as any).antiForgeryToken;
        }

        // Check for API key in window object
        if ((window as any).apiKey) {
          return (window as any).apiKey;
        }

        // Check for CSRF in localStorage
        const localCsrf = localStorage.getItem('csrfToken') || localStorage.getItem('X-CSRF-Token');
        if (localCsrf) {
          return localCsrf;
        }

        // Check for __RequestVerificationToken in hidden inputs
        const input = document.querySelector('input[name="__RequestVerificationToken"]') as HTMLInputElement;
        if (input) {
          return input.value;
        }

        return null;
      });

      await browser.close();

      // Use header CSRF token if found, otherwise use page token
      const finalToken = csrfFromHeader || csrfToken;

      if (finalToken) {
        console.log(`     ✅ Got CSRF token`);
      } else {
        console.log(`     ⚠️  No CSRF token found, will try with cookies only`);
      }

      return { token: finalToken, cookies: cookieHeader };
    } catch (error) {
      await browser.close();
      throw error;
    }
  } catch {
    return { token: null, cookies: "" };
  }
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
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
    };

    // Try multiple approaches for authentication
    const attempts = [
      // Attempt 1: X-Api-Key header (standard)
      async () => {
        headers["X-Api-Key"] = service.apiKey;
        return null;
      },
      // Attempt 2: With API key as query parameter
      async () => {
        const urlWithKey = `${url}?apiKey=${encodeURIComponent(service.apiKey)}`;
        delete headers["X-Api-Key"];
        return urlWithKey;
      },
      // Attempt 3: Authorization header with Bearer
      async () => {
        delete headers["X-Api-Key"];
        headers["Authorization"] = `Bearer ${service.apiKey}`;
        return null;
      },
    ];

    // Add CSRF token and cookies if required
    let { token, cookies } = { token: null as string | null, cookies: "" };
    if (service.requiresCsrf) {
      const result = await getCsrfToken(service);
      token = result.token;
      cookies = result.cookies;
    }

    if (cookies) {
      headers["Cookie"] = cookies;
    }
    if (token) {
      headers["X-CSRF-Token"] = token;
    }

    let lastError = "";
    for (const attempt of attempts) {
      const altUrl = await attempt();
      const targetUrl = altUrl || url;

      try {
        const response = await fetch(targetUrl, {
          method: "POST",
          headers,
          body: JSON.stringify(payload),
        });

        if (response.ok) {
          console.log(`  ✅ Added "${indexer.name}" to ${service.name}`);
          return true;
        }

        const error = await response.text();
        lastError = error;
      } catch (e) {
        lastError = String(e);
      }
    }

    console.error(`  ❌ Error adding to ${service.name}: ${lastError}`);
    return false;
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
  console.log("🎬 Syncing Jackett indexers to Sonarr, Radarr, and Listenarr...\n");

  // Validate API keys (at least one service must be configured)
  const hasSonarr = !!CONFIG.sonarr.apiKey;
  const hasRadarr = !!CONFIG.radarr.apiKey;
  const hasListenarr = !!CONFIG.listenarr.apiKey;

  if (!hasSonarr && !hasRadarr && !hasListenarr) {
    console.error("❌ Missing API keys! Please set at least one in .env file:");
    console.error("   SONARR_API_KEY=xxx");
    console.error("   RADARR_API_KEY=xxx");
    console.error("   LISTENARR_API_KEY=xxx");
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
  const sonarrIndexers = hasSonarr ? await getExistingIndexers(CONFIG.sonarr) : [];
  const radarrIndexers = hasRadarr ? await getExistingIndexers(CONFIG.radarr) : [];
  const listenarrIndexers = hasListenarr ? await getExistingIndexers(CONFIG.listenarr) : [];

  const sonarrNames = new Set(sonarrIndexers.map((i) => i.name));
  const radarrNames = new Set(radarrIndexers.map((i) => i.name));
  const listenarrNames = new Set(listenarrIndexers.map((i) => i.name));

  // Category IDs
  const tvCategories = [8000, 8010, 8020, 8030]; // TV
  const movieCategories = [2000, 2010, 2020, 2030, 2040, 2050, 2060, 2070, 2080]; // Movies
  const bookCategories = [8000, 8010, 8020, 8030, 8040, 8050]; // Books & Audiobooks

  let addedToSonarr = 0;
  let addedToRadarr = 0;
  let addedToListenarr = 0;

  for (const indexer of jackettIndexers) {
    console.log(`\n📦 Processing: ${indexer.name} (${indexer.id})`);

    // Sonarr (TV)
    if (hasSonarr) {
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
    }

    // Radarr (Movies)
    if (hasRadarr) {
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

    // Listenarr (Audiobooks)
    if (hasListenarr) {
      const listenarrExists = listenarrNames.has(indexer.name);
      if (listenarrExists) {
        console.log(`  ⏭️  Already in Listenarr, skipping...`);
      } else if (!indexerSupportsCategory(indexer, bookCategories)) {
        console.log(`  ⏭️  Doesn't support Book categories, skipping Listenarr...`);
      } else {
        const added = await addIndexer(
          { ...CONFIG.listenarr, name: "Listenarr", requiresCsrf: true },
          indexer,
          bookCategories
        );
        if (added) addedToListenarr++;
      }
    }
  }

  console.log(`\n✨ Done!`);
  if (hasSonarr) console.log(`   Sonarr: ${addedToSonarr} new indexers added`);
  if (hasRadarr) console.log(`   Radarr: ${addedToRadarr} new indexers added`);
  if (hasListenarr) console.log(`   Listenarr: ${addedToListenarr} new indexers added`);
}

main().catch((error) => {
  console.error("Error:", error);
  process.exit(1);
});
