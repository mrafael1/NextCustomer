// Writes the #128 chain stills to ../produce_chain_128/: each variant x each belt row at 1280 px
// (the frame only), each row's Today frame, the default variant's good row with a Strawberries
// CHAIN chip hovered (its chain lit) and the wrong row with its tomato Lemon chip hovered, and the
// default variant's good row page at 390 px. Clears old stills first.
// Run: NODE_PATH=<folder with playwright> CHROMIUM_PATH=<chrome.exe> node stills.js
// Fails (exit 1) on a page error, a console error, a failed request or sideways scroll at 390 px.
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');

const PAGE = 'file:///' + path.resolve(__dirname, '..', 'produce_chain_128.html').split(path.sep).join('/');
const OUT = path.resolve(__dirname, '..', 'produce_chain_128');
const VARIANTS = ['rings', 'bars', 'links'];
const ROWS = ['good', 'pair', 'wrong', 'split', 'twofor'];

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  for (const f of fs.readdirSync(OUT)) if (f.endsWith('.png')) fs.unlinkSync(path.join(OUT, f));
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH });
  const errors = [];
  const open = async (width, height, query) => {
    const page = await browser.newPage({ viewport: { width, height } });
    page.on('pageerror', e => errors.push(`${query}: ${e.message}`));
    page.on('console', m => { if (m.type() === 'error') errors.push(`${query}: ${m.text()}`); });
    page.on('requestfailed', r => errors.push(`${query}: failed ${r.url()}`));
    await page.goto(`${PAGE}?${query}`);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(400);
    return page;
  };
  const written = [];
  const shoot = async (page, name) => {
    const file = path.join(OUT, name);
    await (await page.$('#frame')).screenshot({ path: file });
    written.push(file);
  };
  for (const v of VARIANTS) {
    for (const row of ROWS) {
      const page = await open(1280, 900, `v=${v}&row=${row}&view=new`);
      await shoot(page, `${v}_${row}_1280.png`);
      await page.close();
    }
  }
  for (const row of ROWS) {
    const page = await open(1280, 900, `row=${row}&view=now`);
    await shoot(page, `today_${row}_1280.png`);
    await page.close();
  }
  for (const [row, sel, name] of [['good', '.txt .kw', 'hover_good'], ['wrong', '.txt .kw.bad', 'hover_wrong']]) {
    const page = await open(1280, 1300, `row=${row}&view=new`);
    const v = await page.$eval('#varSeg [aria-pressed="true"]', b => b.id.replace('var-', ''));
    await page.hover(sel);
    const tip = await page.$eval('.tip', t => t.textContent).catch(() => '');
    if (!tip) errors.push(`${name}: no tooltip`);
    if (row === 'wrong' && !/WASTED/.test(tip)) errors.push(`${name}: no WASTED tip ("${tip}")`);
    if (row === 'good' && !(await page.$('.ck-svg g.lit'))) errors.push(`${name}: the chain did not light`);
    await shoot(page, `${v}_${name}_1280.png`);
    await page.close();
  }
  const page = await open(390, 844, 'row=good&view=new');
  const v = await page.$eval('#varSeg [aria-pressed="true"]', b => b.id.replace('var-', ''));
  const scroll = await page.evaluate(() => document.documentElement.scrollWidth - innerWidth);
  if (scroll > 0) errors.push(`390 px: page scrolls sideways by ${scroll}px`);
  const file = path.join(OUT, `${v}_good_390.png`);
  await page.screenshot({ path: file, fullPage: true });
  written.push(file);
  await page.close();
  await browser.close();
  written.forEach(f => console.log(f));
  if (errors.length) { console.error(errors.join('\n')); process.exit(1); }
})();
