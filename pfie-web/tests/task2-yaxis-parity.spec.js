import { test, expect } from '@playwright/test';

// Task #2: Y-axis parity between bar chart and trends chart
// Verifies both charts render on the Plots tab after aligning
// bar chart yaxis tickfont size (11→12) and margin.l (44→55).

test.use({ viewport: { width: 1024, height: 768 } });

async function waitForData(page) {
  await expect(page.locator('#caseCount')).not.toContainText('Loading', { timeout: 20000 });
}

test('bar chart and trends chart are both visible on the Plots tab', async ({ page }) => {
  await page.goto('/');
  await waitForData(page);

  // Click the "Plots" tab (role="tab" in the nav)
  await page.getByRole('tab', { name: 'Plots' }).click();

  // Wait for Plotly to render
  await page.waitForTimeout(2000);

  // Both charts should be visible
  await expect(page.locator('#barChart')).toBeVisible();
  await expect(page.locator('#trendsMain')).toBeVisible();
});
