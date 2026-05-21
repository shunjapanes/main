import { test, expect } from '@playwright/test';
import { gotoApp, getEditorFrame, getEditorEvalFrame, loadContent, sendToEditor } from './helpers';

const TSV_A = 'Name\tAge\nAlice\t30\nBob\t25\n';
const TSV_B = 'Product\tPrice\nApple\t100\nBanana\t80\n';

test.describe('ファイル読み込み', () => {
  test('TSVコンテンツを読み込むとテーブルに行が表示される', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A);

    const editorFrame = getEditorFrame(page);
    const rows = editorFrame.locator('#tbody tr');
    await expect(rows).toHaveCount(2);

    // 1行目のデータを確認
    const firstCell = rows.first().locator('td').nth(1); // 0番目はrow番号セル
    await expect(firstCell).toHaveText('Alice');
  });

  test('ヘッダーが正しく表示される', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A);

    const editorFrame = getEditorFrame(page);
    const frame = await getEditorEvalFrame(page);
    const headers = await frame.evaluate(() => {
      // ヘッダーテキストは .th-label スパンに入っている
      return Array.from(document.querySelectorAll('#thead .th-label'))
        .map(el => el.textContent?.trim() || '');
    });

    expect(headers).toContain('Name');
    expect(headers).toContain('Age');
  });

  test('2つ目のファイルを読み込むとタブが2つになる', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A, 'fileA.tsv');

    // 2つ目のファイルを新規シートとして追加
    await sendToEditor(page, 'addSheet');
    await page.waitForTimeout(300);
    await sendToEditor(page, 'openContent', { content: TSV_B, filename: 'fileB.tsv' });

    const editorFrame = getEditorFrame(page);
    await editorFrame.locator('#tbody tr').first().waitFor({ timeout: 5000 });

    // タブバー（Reactのリボン側）に2つのタブが表示される
    const frame = await getEditorEvalFrame(page);
    const tabCount = await frame.evaluate(() => {
      return document.querySelectorAll('#tab-bar .tab-item').length;
    });
    expect(tabCount).toBe(2);
  });
});
