import { test, expect } from '@playwright/test';
import { gotoApp, getEditorFrame, loadContent, sendToEditor } from './helpers';

const TSV_A = 'Name\tAge\nAlice\t30\nBob\t25\n';
const TSV_B = 'Product\tPrice\nApple\t100\nBanana\t80\n';

test.describe('シート追加', () => {
  test('シート追加後はファイル読込画面が表示される', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A, 'fileA.tsv');

    await sendToEditor(page, 'addSheet');

    const editorFrame = getEditorFrame(page);
    await expect(editorFrame.locator('#drop-zone')).toBeVisible();
    await expect(editorFrame.locator('#btn-drop-open')).toBeVisible();
    await expect(editorFrame.locator('#table-container')).toBeHidden();
  });

  test('読込画面からファイルを開くと新しいシートに表示される', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A, 'fileA.tsv');
    await sendToEditor(page, 'addSheet');
    await sendToEditor(page, 'openContent', { content: TSV_B, filename: 'fileB.tsv' });

    const editorFrame = getEditorFrame(page);
    await expect(editorFrame.locator('#table-container')).toBeVisible();
    await expect(editorFrame.locator('#drop-zone')).toBeHidden();
    await expect(editorFrame.locator('#tbody tr').first().locator('td').nth(1)).toHaveText('Apple');
    await expect(editorFrame.locator('#tab-bar .tab-item')).toHaveCount(2);
  });

  test('元のシートに戻るとデータが表示され、空白シートに戻ると読込画面になる', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A, 'fileA.tsv');
    await sendToEditor(page, 'addSheet');

    const editorFrame = getEditorFrame(page);
    await sendToEditor(page, 'switchTab', 0);
    await expect(editorFrame.locator('#table-container')).toBeVisible();
    await expect(editorFrame.locator('#drop-zone')).toBeHidden();

    await sendToEditor(page, 'switchTab', 1);
    await expect(editorFrame.locator('#drop-zone')).toBeVisible();
  });

  test('「空のシートで編集」でグリッドが表示される', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A, 'fileA.tsv');
    await sendToEditor(page, 'addSheet');

    const editorFrame = getEditorFrame(page);
    await editorFrame.locator('#btn-drop-blank').click();
    await expect(editorFrame.locator('#table-container')).toBeVisible();
    await expect(editorFrame.locator('#drop-zone')).toBeHidden();
  });
});

test.describe('リボンから削除したボタン', () => {
  test('上書き保存・フィルター・昇順・降順・重複強調・列統計が表示されない', async ({ page }) => {
    await gotoApp(page);
    const tabs: Record<string, string[]> = {
      'ファイル': ['上書き保存'],
      'ホーム': ['フィルター', '昇順', '降順'],
      '表示': ['重複強調'],
      'ツール': ['列統計'],
    };
    for (const [tab, labels] of Object.entries(tabs)) {
      await page.getByRole('button', { name: tab, exact: true }).click();
      for (const label of labels) {
        await expect(page.getByRole('button', { name: label, exact: true })).toHaveCount(0);
      }
    }
    // 名前を付けて保存は残す
    await page.getByRole('button', { name: 'ファイル', exact: true }).click();
    await expect(page.getByRole('button', { name: '名前を付けて保存', exact: true })).toBeVisible();
  });
});
