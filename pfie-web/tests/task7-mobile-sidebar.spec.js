import { test, expect } from '@playwright/test';

test.describe('Task #7 — Mobile sidebar toggle accessibility', () => {
  test.use({ viewport: { width: 375, height: 812 } });

  test('sidebar toggle stays visible when sidebar is open, and can close sidebar', async ({ page }) => {
    await page.goto('/');

    // Wait for data to load
    await expect(page.locator('#caseCount')).not.toContainText('Loading', { timeout: 20000 });

    // Open the sidebar
    await page.locator('#sidebarToggle').click();

    // Toggle should remain visible even with sidebar open
    await expect(page.locator('#sidebarToggle')).toBeVisible();

    // Close the sidebar
    await page.locator('#sidebarToggle').click();

    // Sidebar should now have .collapsed class
    await expect(page.locator('#sidebar')).toHaveClass(/collapsed/);
  });
});
