// Writes the stills of ../ambiance_123.html: one bare 1280x720 stage per time of day, the clear
// zones, and the page top. Run build.py first.
// Usage: node docs/art/mockups/ambiance_123_src/stills.js (CHROMIUM_PATH picks the browser).
const { chromium } = require('playwright');
const path = require('path');

const page_path = path.resolve(__dirname, '..', 'ambiance_123.html');
const out = (name) => path.resolve(__dirname, '..', `ambiance_123_${name}.png`);
const SHOTS = [
  ['game', 'solo=1&tod=game'],
  ['morning', 'solo=1&tod=morning'],
  ['midday', 'solo=1&tod=midday'],
  ['dusk', 'solo=1&tod=dusk'],
  ['night', 'solo=1&tod=night'],
  ['night_zones', 'solo=1&tod=night&zones=1'],
];

(async () => {
  const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
  for (const [name, query] of SHOTS) {
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
    await page.goto('file://' + page_path + '?' + query);
    await page.waitForSelector('body[data-ready="1"]');
    await page.evaluate(() => document.fonts.ready);
    if ((await page.title()).startsWith('ERROR')) throw new Error(await page.title());
    await page.locator('canvas#stage').screenshot({ path: out(name) });
    console.log('wrote', out(name));
    await page.close();
  }
  const page = await browser.newPage({ viewport: { width: 1344, height: 1400 } });
  await page.goto('file://' + page_path + '?tod=night');
  await page.waitForSelector('body[data-ready="1"]');
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: out('page_top') });
  console.log('wrote', out('page_top'));
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
