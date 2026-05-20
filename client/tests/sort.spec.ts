import { test, expect } from '@playwright/test';
import { gotoApp, getEditorFrame, loadContent, sendToEditor } from './helpers';

const TSV = 'Name\tScore\nAlice\t100\nBob\t200\nCarol\t50\n';

test.describe('ソート', () => {
  test('昇順ソートで先頭データ行も並び替え対象になる', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV, 'scores.tsv');

    const editorFrame = getEditorFrame(page);
    await editorFrame.locator('#tbody tr').first().locator('td').nth(2).click();

    await sendToEditor(page, 'sortAsc');

    await expect(editorFrame.locator('#tbody tr').first().locator('td').nth(1)).toHaveText('Carol');
    await expect(editorFrame.locator('#tbody tr').nth(1).locator('td').nth(1)).toHaveText('Alice');
    await expect(editorFrame.locator('#tbody tr').nth(2).locator('td').nth(1)).toHaveText('Bob');
  });
});
