import { test, expect } from '@playwright/test';
import { gotoApp, getEditorFrame, loadContent, sendToEditor } from './helpers';

const TSV = 'Name\tCity\nAlice\tTokyo\nBob\tOsaka\nCarol\tTokyo\n';

test.describe('行操作', () => {
  test('フィルター中に行を移動しても絞り込み表示が再計算される', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV, 'cities.tsv');

    const editorFrame = getEditorFrame(page);
    await sendToEditor(page, 'toggleFilter');
    const filterInput = editorFrame.locator('.filter-input[data-fcol="1"]');
    await filterInput.waitFor({ state: 'visible', timeout: 5000 });
    await filterInput.fill('Tokyo');

    await expect(editorFrame.locator('#tbody tr')).toHaveCount(2);
    await expect(editorFrame.locator('#tbody tr').nth(1).locator('td').nth(1)).toHaveText('Carol');

    await editorFrame.locator('#tbody tr').nth(1).locator('td').nth(1).click();
    await sendToEditor(page, 'moveRowUp');

    await expect(editorFrame.locator('#tbody tr')).toHaveCount(2);
    await expect(editorFrame.locator('#tbody tr').nth(0).locator('td').nth(1)).toHaveText('Alice');
    await expect(editorFrame.locator('#tbody tr').nth(1).locator('td').nth(1)).toHaveText('Carol');
  });
});

test.describe('列操作', () => {
  test('フィルター対象列を削除したら絞り込みが解除されて全行が表示される', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV, 'cities.tsv');

    const editorFrame = getEditorFrame(page);
    await sendToEditor(page, 'toggleFilter');
    const filterInput = editorFrame.locator('.filter-input[data-fcol="1"]');
    await filterInput.waitFor({ state: 'visible', timeout: 5000 });
    await filterInput.fill('Tokyo');

    await expect(editorFrame.locator('#tbody tr')).toHaveCount(2);
    await editorFrame.locator('#tbody tr').first().locator('td').nth(2).click();
    await sendToEditor(page, 'deleteCols');

    await expect(editorFrame.locator('#tbody tr')).toHaveCount(3);
    await expect(editorFrame.locator('#tbody tr').nth(0).locator('td').nth(1)).toHaveText('Alice');
    await expect(editorFrame.locator('#tbody tr').nth(1).locator('td').nth(1)).toHaveText('Bob');
    await expect(editorFrame.locator('#tbody tr').nth(2).locator('td').nth(1)).toHaveText('Carol');
  });
});
