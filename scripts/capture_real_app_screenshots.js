const path = require("path");
const { chromium } = require("playwright");

async function saveShot(page, outputDir, fileName) {
  await page.screenshot({
    path: path.join(outputDir, fileName),
    fullPage: false,
    animations: "disabled",
  });
}

async function login(page) {
  await page.mouse.click(1030, 705);
  await page.keyboard.type("demo123");
  await page.mouse.click(1025, 780);
  await page.waitForTimeout(1200);
}

async function main() {
  const outputDir =
    process.argv[2] ||
    path.join(process.cwd(), "artifacts", "screenshots");
  const baseUrl = process.argv[3] || "http://localhost:3200";

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({
    viewport: { width: 1440, height: 1400 },
    deviceScaleFactor: 1,
  });

  try {
    await page.goto(baseUrl, { waitUntil: "networkidle" });
    await saveShot(page, outputDir, "real-01-login.png");

    await login(page);
    await saveShot(page, outputDir, "real-02-dashboard.png");

    await page.mouse.click(510, 255);
    await page.keyboard.type("toner");
    await page.waitForTimeout(500);
    await saveShot(page, outputDir, "real-03-search.png");

    await page.mouse.click(515, 332);
    await page.waitForTimeout(500);
    await saveShot(page, outputDir, "real-04-detail-modal.png");

    await page.keyboard.press("Escape");
    await page.waitForTimeout(300);
    await page.mouse.click(1095, 503);
    await page.waitForTimeout(400);
    await saveShot(page, outputDir, "real-05-status-dialog.png");
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
