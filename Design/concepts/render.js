// Renders every mock HTML in /tmp/jarz-mocks into a 3x PNG screenshot.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const dir = '/tmp/jarz-mocks';
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.html'));
  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: { width: 430, height: 932 },
    deviceScaleFactor: 3,
  });
  const page = await context.newPage();
  for (const file of files) {
    await page.goto('file://' + path.join(dir, file));
    await page.waitForTimeout(400);
    const out = path.join(dir, file.replace('.html', '.png'));
    await page.screenshot({ path: out });
    console.log('rendered', out);
  }
  await browser.close();
})();
