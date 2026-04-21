const path = require("path");
const { chromium } = require("playwright");

async function saveShot(page, targetPath, options = {}) {
  await page.screenshot({
    path: targetPath,
    fullPage: false,
    animations: "disabled",
    ...options,
  });
  console.log(`Saved ${targetPath}`);
}

async function main() {
  const outputDir =
    process.argv[2] ||
    path.join(process.cwd(), "artifacts", "screenshots");
  const baseUrl = process.argv[3] || "http://127.0.0.1:8000";

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({
    viewport: { width: 1440, height: 1800 },
    deviceScaleFactor: 1,
  });

  try {
    await page.goto(baseUrl, { waitUntil: "networkidle" });

    await saveShot(page, path.join(outputDir, "01-login.png"));

    await page.click('button[type="submit"]');
    await page.waitForSelector('[data-screen="dashboard"].active');
    await page.waitForTimeout(250);
    await saveShot(page, path.join(outputDir, "02-dashboard.png"));

    await page.click("#toggle-filters-btn");
    await page.waitForSelector("#filters-panel:not(.hidden)");
    await page.fill("#search-input", "toner");
    await page.selectOption("#filter-status", "2");
    await page.click("#apply-filters-btn");
    await page.waitForTimeout(250);
    await saveShot(page, path.join(outputDir, "03-search-filters.png"));

    await page.fill("#search-input", "");
    await page.selectOption("#filter-status", "");
    await page.click("#apply-filters-btn");
    await page.waitForTimeout(250);

    await page.click(".request-card .request-main");
    await page.waitForSelector("#detail-modal:not(.hidden)");
    await page.waitForTimeout(250);
    await saveShot(page, path.join(outputDir, "04-request-detail.png"));

    await page.click("#close-detail-btn");
    await page.waitForSelector("#detail-modal.hidden");
    await page.waitForTimeout(150);

    await page.click("#open-create-btn");
    await page.waitForSelector("#create-modal:not(.hidden)");
    await page.selectOption("#brand_id", { index: 1 });
    await page.waitForTimeout(150);
    await page.selectOption("#brand_model_id", { index: 1 });
    await page.selectOption("#machine_id", { index: 1 });
    await page.selectOption("#part_category_id", { index: 1 });
    await page.fill("#part_name", "Transfer Belt Assembly");
    await page.selectOption("#status", "1");
    await page.fill("#cost", "845.00");
    await page.fill(
      "#description",
      "Replace the worn transfer belt to resolve print quality issues."
    );
    await page.fill(
      "#remark",
      "Urgent request for service unit scheduled this afternoon."
    );
    await page.waitForTimeout(250);
    await saveShot(page, path.join(outputDir, "05-create-request.png"));

    await page.click("#close-create-btn");
    await page.waitForSelector("#create-modal.hidden");
    await page.waitForTimeout(150);

    await page.click('.request-card:first-child .status-fab:nth-child(5)');
    await page.waitForTimeout(300);
    await saveShot(page, path.join(outputDir, "06-status-update.png"));
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
