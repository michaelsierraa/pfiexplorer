import { test, expect } from '@playwright/test';

// Task #3: Link LOESS trace visibility to scatter legend toggle via legendgroup
// Verifies the trends chart renders and contains legend items after adding
// legendgroup to both scatter and LOESS traces in updateTrendsChart().

test.use({ viewport: { width: 1024, height: 768 } });

async function waitForData(page) {
  await expect(page.locator('#caseCount')).not.toContainText('Loading', { timeout: 20000 });
}

test('trends chart renders with legend items on the Plots tab', async ({ page }) => {
  await page.goto('/');
  await waitForData(page);

  // Click the "Plots" tab
  await page.getByRole('tab', { name: 'Plots' }).click();

  // Wait for Plotly to render
  await page.waitForTimeout(2000);

  // The trends chart container should be visible
  await expect(page.locator('#trendsMain')).toBeVisible();

  // The Plotly SVG inside #trendsMain should contain at least one legend text element
  // Plotly renders legend labels as <text class="legendtext"> inside the SVG
  const legendItems = page.locator('#trendsMain .legendtext');
  await expect(legendItems).not.toHaveCount(0);
});
