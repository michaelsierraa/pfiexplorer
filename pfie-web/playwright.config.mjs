import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  use: {
    baseURL: 'http://localhost:8080',
  },
  // Run tests in a single worker so the dev server is shared
  workers: 1,
});
