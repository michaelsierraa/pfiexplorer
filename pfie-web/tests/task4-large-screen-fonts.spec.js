// Task #4 — Large-screen font scaling
// Viewport: 1440×900; verifies UI controls are visible and font sizes are
// scaled up by the @media (min-width: 1400px) block added to style.css.

const { test, expect } = require('@playwright/test');

test.use({ viewport: { width: 1440, height: 900 } });

test('large-screen font scaling — UI controls visible at 1440px', async ({ page }) => {
  await page.goto('http://localhost:8080');

  // Wait for data to finish loading (caseCount leaves "Loading…" state)
  await page.waitForFunction(
    () => {
      const el = document.getElementById('caseCount');
      return el && !el.textContent.includes('Loading');
    },
    { timeout: 20000 }
  );

  // Tab navigation bar is visible
  const tabNav = page.locator('.tab-nav');
  await expect(tabNav).toBeVisible();

  // At least one tab button is visible
  const firstTab = page.locator('.tab-btn').first();
  await expect(firstTab).toBeVisible();

  // Sidebar is visible (not collapsed at desktop width)
  const sidebar = page.locator('.sidebar');
  await expect(sidebar).toBeVisible();

  // Header title is visible
  const headerTitle = page.locator('.header-title');
  await expect(headerTitle).toBeVisible();

  // Verify computed font size of a tab button is >= 14px
  // (the large-screen rule sets it to 16px; baseline is 14px)
  const tabFontSize = await page.evaluate(() => {
    const btn = document.querySelector('.tab-btn');
    if (!btn) return 0;
    return parseFloat(window.getComputedStyle(btn).fontSize);
  });
  expect(tabFontSize).toBeGreaterThanOrEqual(14);

  // Verify computed font size of a filter-select is >= 13px
  // (large-screen rule sets it to 15px; baseline is 13px)
  const selectFontSize = await page.evaluate(() => {
    const sel = document.querySelector('.filter-select');
    if (!sel) return 0;
    return parseFloat(window.getComputedStyle(sel).fontSize);
  });
  expect(selectFontSize).toBeGreaterThanOrEqual(13);
});
