import { readFile } from 'node:fs/promises';
import { test, expect } from '@playwright/test';
import { gotoApp, getEditorFrame, loadContent, sendToEditor } from './helpers';

const TSV = 'Name\tCity\nAlice\tTokyo\nBob\tOsaka\n';

test.describe('出力', () => {
  test('フィルター結果が0行のTSV出力で全行を出力しない', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV, 'cities.tsv');

    const editorFrame = getEditorFrame(page);
    await sendToEditor(page, 'toggleFilter');
    const filterInput = editorFrame.locator('.filter-input[data-fcol="1"]');
    await filterInput.waitFor({ state: 'visible', timeout: 5000 });
    await filterInput.fill('Nagoya');
    await expect(editorFrame.locator('#tbody tr')).toHaveCount(0);

    const downloadPromise = page.waitForEvent('download');
    await sendToEditor(page, 'exportTsv');
    const download = await downloadPromise;
    const filePath = await download.path();
    expect(filePath).toBeTruthy();

    const text = await readFile(filePath!, 'utf8');
    expect(text.trim()).toBe('Name\tCity');
    expect(text).not.toContain('Alice\tTokyo');
    expect(text).not.toContain('Bob\tOsaka');
  });
});
