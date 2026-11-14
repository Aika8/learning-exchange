import { defineConfig, devices } from '@playwright/test';

// Needs the backend: run `make dev` first. Vite is started here if it is not running yet.
export default defineConfig({
  testDir: 'e2e',
  timeout: 30_000,
  use: { baseURL: 'http://localhost:5173', screenshot: 'only-on-failure' },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: { command: 'npm run dev', url: 'http://localhost:5173', reuseExistingServer: true },
});
