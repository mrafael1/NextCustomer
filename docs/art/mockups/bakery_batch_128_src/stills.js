// Writes the #128 batch stills to ../bakery_batch_128/: each Batch variant x each belt row at
// 1280 px (the frame only), the default variant's "Bread first" frame with its tomato BATCH chip
// hovered, and that variant's "Bread first" page at 390 px. Clears stills of unlisted variants.
// Run: NODE_PATH=<folder with playwright> CHROMIUM_PATH=<chrome.exe> node stills.js
// Fails (exit 1) on a page error, a console error or a missing variant.
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');

const PAGE = 'file:///' + path.resolve(__dirname, '..', 'bakery_batch_128.html').replace(/\\/g, '/');
const OUT = path.resolve(__dirname, '..', 'bakery_batch_128');
const VARIANTS = ['stripb', 'stripa', 'stripc', 'band', 'bracket'];
const ROWS = ['bad', 'good'];

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  for (const f of fs.readdirSync(OUT)) if (f.endsWith('.png')) fs.unlinkSync(path.join(OUT, f));
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH });
  const errors = [];
  const open = async (width, height, query) => {
    const page = await browser.newPage({ viewport: { width, height } });
    page.on('pageerror', e => errors.push(`${query}: ${e.message}`));
    page.on('console', m => { if (m.type() === 'error') errors.push(`${query}: ${m.text()}`); });
    await page.goto(`${PAGE}?${query}`);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(500);
    return page;
  };
  const written = [];
  for (const v of VARIANTS) {
    for (const row of ROWS) {
      const query = `v=${v}&row=${row}&view=new`;
      const page = await open(1280, 900, query);
      const pressed = await page.$eval('#varSeg [aria-pressed="true"]', b => b.id).catch(() => '');
      if (pressed !== `var-${v}`) errors.push(`${query}: variant button not pressed (${pressed})`);
      const title = await page.title();
      if (!title || /error/i.test(title)) errors.push(`${query}: page title "${title}"`);
      const file = path.join(OUT, `${v}_${row}_1280.png`);
      await (await page.$('#frame')).screenshot({ path: file });
      written.push(file);
      await page.close();
    }
  }
  {
    // Tall enough that the frame needs no scroll: a scroll would move it from under the mouse.
    const page = await open(1280, 1300, 'row=bad&view=new');
    const v = await page.$eval('#varSeg [aria-pressed="true"]', b => b.id.replace('var-', ''));
    await page.hover('.kw.bad');
    const tip = await page.$eval('.tip', t => t.textContent).catch(() => '');
    if (!/WASTED/.test(tip)) errors.push(`hover: the bad BATCH chip shows no WASTED tip ("${tip}")`);
    const file = path.join(OUT, `${v}_bad_hover_1280.png`);
    await (await page.$('#frame')).screenshot({ path: file });
    written.push(file);
    await page.close();
  }
  const page = await open(390, 844, 'row=bad&view=new');
  const v = await page.$eval('#varSeg [aria-pressed="true"]', b => b.id.replace('var-', ''));
  const scroll = await page.evaluate(() => document.documentElement.scrollWidth - innerWidth);
  if (scroll > 0) errors.push(`390 px: page scrolls sideways by ${scroll}px`);
  const file = path.join(OUT, `${v}_bad_390.png`);
  await page.screenshot({ path: file, fullPage: true });
  written.push(file);
  await page.close();
  await browser.close();
  written.forEach(f => console.log(f));
  if (errors.length) { console.error(errors.join('\n')); process.exit(1); }
})();
