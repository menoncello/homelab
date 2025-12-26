#!/usr/bin/env bun
/**
 * List Jackett indexers that support audiobooks (category 8040)
 * Fetches categories from each indexer's config endpoint
 */

import { config } from "dotenv";
import puppeteer from "puppeteer";

config();

const JACKETT_URL = process.env.JACKETT_URL || "http://192.168.31.75:9117";

interface JackettIndexer {
  id: string;
  name: string;
  type: string;
  link: string;
  configured?: boolean;
}

interface IndexerConfig {
  caps?: {
    categories: Array<{ id: number; name: string }>;
  };
}

async function getJackettCookies(): Promise<string> {
  console.log("🔐 Connecting to Jackett...");

  const browser = await puppeteer.launch({
    headless: true,
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
  });

  try {
    const page = await browser.newPage();
    await page.goto(JACKETT_URL, {
      waitUntil: "networkidle2",
      timeout: 30000,
    });

    const cookies = await page.cookies();
    await browser.close();

    return cookies.map((c) => `${c.name}=${c.value}`).join("; ");
  } catch (error) {
    await browser.close();
    throw error;
  }
}

async function getIndexers(cookies: string): Promise<JackettIndexer[]> {
  const response = await fetch(`${JACKETT_URL}/api/v2.0/indexers`, {
    headers: { "Cookie": cookies },
  });

  const data = await response.json();
  return Object.values(data);
}

async function getIndexerConfig(indexerId: string, cookies: string): Promise<IndexerConfig> {
  try {
    const response = await fetch(`${JACKETT_URL}/api/v2.0/indexers/${indexerId}/config`, {
      headers: { "Cookie": cookies },
    });

    if (!response.ok) {
      return {};
    }

    return await response.json();
  } catch {
    return {};
  }
}

function supportsAudiobooks(categories: number[] | undefined): boolean {
  if (!categories) return false;
  return categories.includes(8040);
}

async function main() {
  const cookies = await getJackettCookies();
  console.log("📡 Fetching indexers...\n");

  const indexers = await getIndexers(cookies);
  console.log(`   Found ${indexers.length} total indexers\n`);

  const audiobookIndexers: Array<{
    name: string;
    id: string;
    categories: number[];
    torznab: string;
    link: string;
  }> = [];

  // Fetch config for each indexer
  for (const idx of indexers) {
    const config = await getIndexerConfig(idx.id, cookies);
    const categories = config.caps?.categories?.map((c) => c.id) || [];

    if (supportsAudiobooks(categories)) {
      audiobookIndexers.push({
        name: idx.name,
        id: idx.id,
        categories,
        torznab: `${JACKETT_URL}/api/${idx.id}`,
        link: idx.link,
      });
    }
  }

  console.log(`✅ Found ${audiobookIndexers.length} indexers with Audiobook support (8040):\n`);

  audiobookIndexers.forEach((idx) => {
    console.log(`📚 ${idx.name} (${idx.id})`);
    console.log(`   Categories: ${idx.categories.join(",")}`);
    console.log(`   Torznab: ${idx.torznab}`);
    console.log(`   Link: ${idx.link}`);
    console.log("");
  });

  // Generate TSV for audiobook indexers
  const tsvHeader = "Name\tTorznab Feed URL\tCategories\tAPI Key\n";
  const tsvRows = audiobookIndexers.map((idx) => {
    const cats = idx.categories.join(",");
    return `${idx.name}\t${idx.torznab}\t${cats}\tYOUR_JACKETT_API_KEY`;
  }).join("\n");

  await Bun.write("audiobook-indexers.tsv", tsvHeader + tsvRows);
  console.log(`📄 Exported to audiobook-indexers.tsv`);
}

main().catch(console.error);
