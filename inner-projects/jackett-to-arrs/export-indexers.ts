#!/usr/bin/env bun
/**
 * Export Jackett indexers to TSV file
 *
 * Usage: bun export-indexers.ts
 *
 * Generates: indexers.tsv with columns:
 * - Name
 * - Torznab Feed URL
 * - Categories (comma-separated IDs)
 * - API Key
 */

import { config } from "dotenv";
import puppeteer from "puppeteer";

config();

const CONFIG = {
  jackett: {
    url: process.env.JACKETT_URL || "http://192.168.31.5:9117",
    apiKey: process.env.JACKETT_API_KEY || "",
  },
};

interface JackettIndexer {
  id: string;
  name: string;
  type: string;
  link: string;
  configured: boolean;
  caps?: {
    categories: Array<{ id: number; name: string }>;
  };
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

    const cookies = await page.cookies();
    await browser.close();

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
 * Fetch all indexers from Jackett
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

    // Get all indexers (configured + public)
    const indexers = Object.values(data).map((i: any) => ({
      id: i.id,
      name: i.name,
      type: i.type,
      link: i.link,
      configured: i.configured || false,
      caps: i.caps,
    }));

    console.log(`   Found ${indexers.length} total indexers\n`);

    return indexers;
  } catch (error) {
    console.error("❌ Error fetching Jackett indexers:", error);
    return [];
  }
}

/**
 * Get Jackett API key from the web UI
 */
async function getJackettApiKey(): Promise<string> {
  try {
    console.log("🔑 Getting Jackett API key from web UI...");

    const browser = await puppeteer.launch({
      headless: true,
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });

    try {
      const page = await browser.newPage();
      await page.goto(`${CONFIG.jackett.url}/UI/Dashboard`, {
        waitUntil: "networkidle2",
        timeout: 30000,
      });

      const apiKey = await page.evaluate(() => {
        // Try to find API key in the page
        const inputs = document.querySelectorAll('input[value*="api"]');
        for (const input of Array.from(inputs)) {
          const value = (input as HTMLInputElement).value;
          if (value && value.length > 20) {
            return value;
          }
        }

        // Check for API key in localStorage
        if (localStorage.getItem('jackett_api_key')) {
          return localStorage.getItem('jackett_api_key');
        }

        return null;
      });

      await browser.close();

      if (apiKey) {
        console.log("   ✅ Got API key from UI");
        return apiKey;
      }

      console.log("   ⚠️  API key not found in UI, using env or default");
      return CONFIG.jackett.apiKey || "YOUR_JACKETT_API_KEY";
    } catch (error) {
      await browser.close();
      throw error;
    }
  } catch {
    return CONFIG.jackett.apiKey || "YOUR_JACKETT_API_KEY";
  }
}

async function main() {
  console.log("🎬 Exporting Jackett indexers to TSV...\n");

  // Get Jackett session cookies
  const cookies = await getJackettCookies();

  // Get Jackett indexers
  console.log("📡 Fetching indexers from Jackett...");
  const jackettIndexers = await getJackettIndexers(cookies);

  if (jackettIndexers.length === 0) {
    console.error("❌ No indexers found in Jackett!");
    process.exit(1);
  }

  // Debug: Show a sample indexer with categories
  const sampleIndexer = jackettIndexers[0];
  console.log(`\n📋 Sample indexer data:`);
  console.log(`   Name: ${sampleIndexer.name}`);
  console.log(`   Has caps: ${!!sampleIndexer.caps}`);
  if (sampleIndexer.caps?.categories) {
    console.log(`   Categories: ${JSON.stringify(sampleIndexer.caps.categories.slice(0, 5))}...`);
  }

  // Get Jackett API key
  const apiKey = await getJackettApiKey();

  // Generate TSV content
  const tsvHeader = "Name\tTorznab Feed URL\tCategories\tAPI Key\n";
  const tsvRows = jackettIndexers.map((indexer) => {
    const torznabUrl = `${CONFIG.jackett.url}/api/${indexer.id}`;
    const categories = indexer.caps?.categories
      ? indexer.caps.categories.map((c) => c.id).join(",")
      : "";
    return `${indexer.name}\t${torznabUrl}\t${categories}\t${apiKey}`;
  }).join("\n");

  const tsvContent = tsvHeader + tsvRows;

  // Write to file
  const filename = "indexers.tsv";
  await Bun.write(filename, tsvContent);

  console.log(`\n✅ Exported ${jackettIndexers.length} indexers to ${filename}`);
  console.log(`\n📋 Format: Name | Torznab Feed URL | Categories | API Key`);
  console.log(`\n💡 You can import this TSV into:`);
  console.log(`   - Listenarr (Settings → Indexers → Import)`);
  console.log(`   - Readarr (Settings → Indexers → Import)`);
  console.log(`   - Other *arr applications`);
}

main().catch((error) => {
  console.error("Error:", error);
  process.exit(1);
});
