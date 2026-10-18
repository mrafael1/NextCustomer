// Captures a mock-up page at 1920x1080 (the 1280x720 stage at 1.5x).
// Usage: node docs/art/mockups/capture.js <page.html> <out.png>
// Needs Playwright with a Chromium (set CHROMIUM_PATH to use a specific one).
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const [page_path, out_path] = process.argv.slice(2);
  if (!page_path || !out_path) {
    console.error('usage: node capture.js <page.html> <out.png>');
    process.exit(1);
  }
  const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1.5 });
  await page.goto('file://' + path.resolve(page_path));
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(300);
  await page.screenshot({ path: out_path });
  await browser.close();
})();
