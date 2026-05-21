import { test, expect } from '@playwright/test';
import { gotoApp, getEditorEvalFrame, loadContent, sendToEditor } from './helpers';

const TSV = 'Name\tCity\nAlice\tTokyo\nBob\tOsaka\nCarol\tTokyo\n';

test.describe('検索機能', () => {
  test('検索ワードでマッチ数が返る', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV);
    await page.waitForTimeout(300);

    await sendToEditor(page, 'search', 'Tokyo');
    await page.waitForTimeout(800);

    const frame = await getEditorEvalFrame(page);
    const countText = await frame.evaluate(() => {
      return document.getElementById('search-count')?.textContent || '';
    });

    // "2件" または "1/2件" など、2以上の数字が含まれていること
    const nums = countText.match(/\d+/g)?.map(Number) || [];
    expect(countText).toMatch(/[1-9]/);
    expect(nums.some(n => n >= 2)).toBe(true);
  });

  test('searchNextで検索カーソルが進む', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV);
    await page.waitForTimeout(300);

    await sendToEditor(page, 'search', 'Tokyo');
    await page.waitForTimeout(500);

    const frame = await getEditorEvalFrame(page);
    // 最初の検索後は "1/2件" の形式
    const countBefore = await frame.evaluate(() =>
      document.getElementById('search-count')?.textContent || ''
    );

    await sendToEditor(page, 'searchNext');
    await page.waitForTimeout(300);

    const countAfter = await frame.evaluate(() =>
      document.getElementById('search-count')?.textContent || ''
    );

    // カーソルが進んでカウント表示が変わること（"1/2件" → "2/2件"）
    expect(countBefore).not.toBe('');
    expect(countAfter).not.toBe('');
    expect(countBefore).not.toBe(countAfter);
  });

  test('gotoRowで選択セルが指定行に移動する', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV);
    await page.waitForTimeout(300);

    // 3行目（1-indexed）にジャンプ → data-row="2" (0-indexed)
    await sendToEditor(page, 'gotoRow', 3);
    await page.waitForTimeout(400);

    const frame = await getEditorEvalFrame(page);
    // row 2 のtdにselectedクラスが付いていること
    const selectedRow = await frame.evaluate(() => {
      const selected = document.querySelector('#tbody td.selected');
      if (!selected) return -1;
      const tr = selected.closest('tr');
      return parseInt(tr?.getAttribute('data-row') || '-1');
    });

    expect(selectedRow).toBe(2);
  });
});
