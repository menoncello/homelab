#!/usr/bin/env bun
/**
 * List Jackett indexers that support audiobooks (category 8040)
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

function supportsAudiobooks(indexer: JackettIndexer): boolean {
  if (!indexer.caps?.categories) return false;
  const catIds = indexer.caps.categories.map((c) => c.id);
  return catIds.includes(8040);
}

async function main() {
  const cookies = await getJackettCookies();
  console.log("📡 Fetching indexers...\n");

  const indexers = await getIndexers(cookies);

  // Filter for audiobook support
  const audiobookIndexers = indexers.filter(supportsAudiobooks);

  console.log(`✅ Found ${audiobookIndexers.length} indexers with Audiobook support (8040):\n`);

  audiobookIndexers.forEach((idx) => {
    const cats = idx.caps?.categories || [];
    const allCats = cats.map((c) => c.id).join(",");

    console.log(`📚 ${idx.name} (${idx.id})`);
    console.log(`   Categories: ${allCats}`);
    console.log(`   Torznab: ${JACKETT_URL}/api/${idx.id}`);
    console.log(`   Link: ${idx.link}`);
    console.log("");
  });

  // Generate TSV for audiobook indexers
  const tsvHeader = "Name\tTorznab Feed URL\tCategories\tAPI Key\n";
  const tsvRows = audiobookIndexers.map((idx) => {
    const torznabUrl = `${JACKETT_URL}/api/${idx.id}`;
    const cats = idx.caps?.categories?.map((c) => c.id).join(",") || "";
    return `${idx.name}\t${torznabUrl}\t${cats}\tYOUR_API_KEY`;
  }).join("\n");

  await Bun.write("audiobook-indexers.tsv", tsvHeader + tsvRows);
  console.log(`📄 Exported to audiobook-indexers.tsv`);
}

main().catch(console.error);
