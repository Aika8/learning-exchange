import { expect, test } from '@playwright/test';

// Walking skeleton (M1): log in, see the live book from the bots, place / cancel a limit order, fill a market order,
// switch language. Runs against the real backend started by `make dev`.
test('trade on the live market', async ({ page }) => {
  const name = `e2e-${Date.now()}`;
  await page.goto('/');
  await page.getByTestId('lang-en').click();
  await page.getByTestId('login-name').fill(name);
  await page.getByTestId('login-submit').click();

  await expect(page.getByTestId('account-name')).toHaveText(name);
  await expect(page.getByTestId('balance-SILK')).toContainText('1,000');
  await expect(page.getByTestId('ask-row').first()).toBeVisible({ timeout: 10_000 });
  await expect(page.getByTestId('bid-row').first()).toBeVisible();

  // A limit buy far below the market rests in the book and reserves money.
  await page.getByTestId('side-buy').click();
  await page.getByTestId('type-limit').click();
  await page.getByTestId('price').fill('50.00');
  await page.getByTestId('qty').fill('2');
  await page.getByTestId('submit-order').click();
  await expect(page.getByTestId('order-message')).toContainText('New');
  const resting = page.getByTestId('my-orders').locator('tr', { hasText: '50.00' });
  await expect(resting.getByTestId('order-status')).toHaveText('New');
  await expect(page.getByTestId('balance-SPARK')).toContainText('100.10'); // 2 × 50.00 + fee 0.10 reserved

  await resting.getByTestId('cancel-order').click();
  await expect(resting.getByTestId('order-status')).toHaveText('Cancelled');

  // A market buy fills against the market maker.
  await page.getByTestId('type-market').click();
  await page.getByTestId('qty').fill('1');
  await page.getByTestId('submit-order').click();
  await expect(page.getByTestId('order-message')).toContainText('Filled');
  await expect(page.getByTestId('balance-SILK')).toContainText('1,001');

  await page.getByTestId('lang-ru').click();
  await expect(page.getByRole('heading', { name: /Стакан/ })).toBeVisible();
  await page.screenshot({ path: 'test-results/web-skeleton.png', fullPage: true });
});
