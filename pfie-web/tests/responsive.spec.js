import { test, expect } from '@playwright/test';

// Wait for data to load: #caseCount must stop saying "Loading"
async function waitForData(page) {
  await expect(page.locator('#caseCount')).not.toContainText('Loading', { timeout: 20000 });
}

const VIEWPORTS = [
  { name: '375px (mobile)',  width: 375,  height: 812 },
  { name: '720px (tablet)',  width: 720,  height: 1024 },
  { name: '1024px (laptop)', width: 1024, height: 768 },
  { name: '1440px (desktop)',width: 1440, height: 900 },
];

for (const vp of VIEWPORTS) {
  test.describe(`Viewport: ${vp.name}`, () => {
    test.use({ viewport: { width: vp.width, height: vp.height } });

    test('map and legend are visible after data loads', async ({ page }) => {
      await page.goto('/');
      await waitForData(page);

      await expect(page.locator('#pfiemap')).toBeVisible();
      await expect(page.locator('.leaflet-container')).toBeVisible();
      // Legend control rendered by Leaflet
      await expect(page.locator('.leaflet-legend')).toBeVisible();
    });

    test('bar chart is visible on Map tab', async ({ page }) => {
      await page.goto('/');
      await waitForData(page);
      await expect(page.locator('#barChart')).toBeVisible();
    });

    test('trend chart is visible on Map tab (embedded)', async ({ page }) => {
      await page.goto('/');
      await waitForData(page);
      await expect(page.locator('#trendsMain')).toBeVisible();
    });

    if (vp.width <= 900) {
      test('sidebar is collapsed by default on mobile', async ({ page }) => {
        await page.goto('/');
        await waitForData(page);

        const sidebar = page.locator('#sidebar');
        // On mobile the sidebar starts with .collapsed class
        await expect(sidebar).toHaveClass(/collapsed/);
      });

      test('can open sidebar and see filters on mobile', async ({ page }) => {
        await page.goto('/');
        await waitForData(page);

        await page.locator('#sidebarToggle').click();
        const sidebar = page.locator('#sidebar');
        await expect(sidebar).not.toHaveClass(/collapsed/);
        await expect(page.locator('.filter-section').first()).toBeVisible();
      });
    } else {
      test('backdrop is never visible on desktop', async ({ page }) => {
        await page.goto('/');
        await waitForData(page);

        const backdrop = page.locator('#sidebarBackdrop');
        // backdrop should not be visible (CSS hides it on desktop)
        await expect(backdrop).not.toBeVisible();
      });
    }
  });
}

