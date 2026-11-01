// Writes the page's stills (Playwright with Chromium; CHROMIUM_PATH picks one).
//   node docs/art/mockups/family_identities_128_src/stills.js
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const PAGE = path.resolve(__dirname, '..', 'family_identities_128.html');
const OUT = path.resolve(__dirname, '..', 'family_identities_128');
const STILLS = [
  ['page', '', true],
  ['1_repeat', 'sec=1', true],
  ['2_families', 'sec=2', true],
  ['3_produce_lab', 'sec=3&preset=carrot', true],
  ['3b_produce_lab_today', 'sec=3&preset=carrot&rules=now', true],
  ['4_study', 'sec=4', true],
  ['5_findings', 'sec=5', true],
  ['6_questions', 'sec=6', true],
];

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  for (const [name, q, full] of STILLS) {
    await page.goto('file://' + PAGE + (q ? '?' + q : ''));
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(300);
    const title = await page.title();
    if (title.startsWith('ERROR')) errors.push(name + ': ' + title);
    await page.screenshot({ path: path.join(OUT, name + '.png'), fullPage: full });
    console.log('wrote', name);
  }
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('file://' + PAGE + '?sec=2');
  await page.waitForTimeout(300);
  const w = await page.evaluate(() => document.documentElement.scrollWidth);
  if (w > 390) errors.push('phone: page scrolls sideways (' + w + ' px)');
  await page.screenshot({ path: path.join(OUT, 'phone_390.png') });
  await browser.close();
  if (errors.length) { console.error(errors.join('\n')); process.exit(1); }
})();
