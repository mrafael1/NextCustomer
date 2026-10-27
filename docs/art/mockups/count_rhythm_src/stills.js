// Captures stills of ../count_rhythm_v1.html: node stills.js <out folder>
// Each still plays the page up to a beat; "mid" stills then play that beat at 1× and stop
// 300 ms in, while its pop-up is up.
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const out = process.argv[2] || '.';
  const url = 'file://' + path.resolve(__dirname, '..', 'count_rhythm_v1.html');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1320, height: 900 } });
  const shots = [['a', 9, false], ['a', 21, true], ['a', 22, true], ['a', 23, false], ['b', 21, true], ['b', 23, false], ['a', 12, true]];
  for (const [v, beat, mid] of shots) {
    await page.goto(`${url}?v=${v}&beat=${mid ? beat - 1 : beat}`);
    await page.waitForSelector('body[data-ready="1"]', { timeout: 20000 });
    await page.waitForTimeout(mid ? 50 : 400);
    if (mid) { await page.evaluate(n => { window.__beat(n); }, beat); await page.waitForTimeout(300); }
    await (await page.$('#stage-box')).screenshot({ path: path.join(out, `count_rhythm_v1_${v}_beat${beat}${mid ? '_mid' : ''}.png`) });
  }
  await page.goto(url);
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(out, 'count_rhythm_v1_page.png'), fullPage: true });
  await browser.close();
})();
