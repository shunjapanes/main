import { test, expect } from '@playwright/test';
import { gotoApp, getEditorFrame, loadContent, sendToEditor } from './helpers';

const TSV = 'Name\tCity\nAlice\tTokyo\nBob\tOsaka\n';

test.describe('フィルター中の編集', () => {
  test('条件列を編集したら絞り込み表示が再計算される', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV, 'cities.tsv');

    const editorFrame = getEditorFrame(page);
    await sendToEditor(page, 'toggleFilter');
    const filterInput = editorFrame.locator('.filter-input[data-fcol="1"]');
    await filterInput.waitFor({ state: 'visible', timeout: 5000 });
    await filterInput.fill('Tokyo');

    await expect(editorFrame.locator('#tbody tr')).toHaveCount(1);
    const cityCell = editorFrame.locator('#tbody tr').first().locator('td').nth(2);
    await cityCell.dblclick();
    await cityCell.locator('input').fill('Osaka');
    await cityCell.locator('input').press('Enter');

    await expect(editorFrame.locator('#tbody tr')).toHaveCount(0);
  });
});
