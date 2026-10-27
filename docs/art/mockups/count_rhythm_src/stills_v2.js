// Captures stills of ../count_rhythm_v2.html: node stills_v2.js <out folder>
// Each still plays the page fast up to a beat; "mid" stills then play that beat at 1× and stop
// 250 ms in, while its stamp and amount are up.
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const out = process.argv[2] || '.';
  const url = 'file://' + path.resolve(__dirname, '..', 'count_rhythm_v2.html');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1320, height: 900 } });
  const shots = [[1, 8, true], [1, 15, true], [1, 21, true], [1, 22, true], [1, 23, false], [2, 22, true], [2, 23, false]];
  page.on('pageerror', e => console.log('PAGE ERROR', e.message));
  for (const [t, beat, mid] of shots) {
    await page.goto(`${url}?t=${t}&beat=${mid ? beat - 1 : beat}`);
    await page.waitForSelector('body[data-ready="1"]', { timeout: 30000 });
    await page.waitForTimeout(mid ? 50 : 600);
    if (mid) { await page.evaluate(n => { window.__beat(n); }, beat); await page.waitForTimeout(250); }
    await (await page.$('#stage-box')).screenshot({ path: path.join(out, `count_rhythm_v2_t${t}_beat${beat}${mid ? '_mid' : ''}.png`) });
  }
  await page.goto(url);
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(out, 'count_rhythm_v2_page.png'), fullPage: true });
  await browser.close();
})();
