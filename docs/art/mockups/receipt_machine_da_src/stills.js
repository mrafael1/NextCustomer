// Writes the page's stills next to it (Playwright with Chromium; CHROMIUM_PATH picks one).
//   node docs/art/mockups/receipt_machine_da_src/stills.js [only-this-name]
const { chromium } = require('playwright');
const path = require('path');

const PAGE = path.resolve(__dirname, '..', 'receipt_machine_da.html');
const OUT = path.resolve(__dirname, '..', 'receipt_machine_da');
const STILLS = [
  ['1_insert', 'stage=insert&t=0.2'],
  ['2_reading', 'stage=reading&t=0.9'],
  ['3_choose', 'stage=choose&t=0.2'],
  ['3b_choose_hover_new', 'stage=choose&hover=new&t=0.2'],
  ['4_draw', 'stage=draw&t=0.9'],
  ['5_pick', 'stage=reveal&t=0.2'],
  ['5b_pick_hover_legendary', 'stage=reveal&hover=p2&t=0.2'],
  ['5c_pick_hover_bin', 'stage=reveal&hover=bin&t=0.05'],
  ['6_premium_choose', 'stage=choose&premium=1&hover=new&t=0.2'],
  ['6b_premium_pick', 'stage=reveal&premium=1&hover=p2&t=0.2'],
  ['7_body_teal', 'stage=choose&body=teal&t=0.2'],
  ['7_body_tomato', 'stage=choose&body=tomato&t=0.2'],
];

(async () => {
  const only = process.argv[2];
  const fs = require('fs');
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  for (const [name, q] of STILLS) {
    if (only && only !== name) continue;
    await page.goto('file://' + PAGE + '?solo=1&' + q);
    await page.waitForTimeout(500);
    const title = await page.title();
    if (title.startsWith('ERROR')) errors.push(name + ': ' + title);
    await page.screenshot({ path: path.join(OUT, name + '_1280x720.png') });
    console.log('wrote', name);
  }
  if (!only) {
    await page.setViewportSize({ width: 1340, height: 900 });
    await page.goto('file://' + PAGE + '?stage=choose&hover=new&t=0.2');
    await page.waitForTimeout(500);
    await page.screenshot({ path: path.join(OUT, 'page.png'), fullPage: true });
    console.log('wrote page');
  }
  await browser.close();
  if (errors.length) { console.error(errors.join('\n')); process.exit(1); }
})();
