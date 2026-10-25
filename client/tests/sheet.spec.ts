import { test, expect } from '@playwright/test';
import { gotoApp, getEditorFrame, getEditorEvalFrame, loadContent, sendToEditor } from './helpers';

const TSV_A = 'Name\tAge\nAlice\t30\nBob\t25\n';
const TSV_B = 'Product\tPrice\nApple\t100\nBanana\t80\n';

test.describe('新規シート追加', () => {
  test('シートを追加するとファイルを開く画面が表示される', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A, 'fileA.tsv');

    const editorFrame = getEditorFrame(page);
    // ファイル読み込み直後はグリッド表示
    await expect(editorFrame.locator('#drop-zone')).toHaveClass(/hidden/);

    await sendToEditor(page, 'addSheet');
    await expect(editorFrame.locator('#drop-zone')).not.toHaveClass(/hidden/);
    // 空シート用の導線が出ている
    await expect(editorFrame.locator('#btn-drop-blank')).toBeVisible();
  });

  test('「空のシートに直接入力する」でグリッドに切り替わる', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A, 'fileA.tsv');
    await sendToEditor(page, 'addSheet');

    const editorFrame = getEditorFrame(page);
    await editorFrame.locator('#btn-drop-blank').click();

    await expect(editorFrame.locator('#drop-zone')).toHaveClass(/hidden/);
    await expect(editorFrame.locator('#table-container')).toBeVisible();
  });

  test('空シートでファイルを開くとそのシートに読み込まれタブは増えない', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A, 'fileA.tsv');
    await sendToEditor(page, 'addSheet');
    await sendToEditor(page, 'openContent', { content: TSV_B, filename: 'fileB.tsv' });

    const editorFrame = getEditorFrame(page);
    await editorFrame.locator('#tbody tr').first().waitFor({ timeout: 5000 });
    await expect(editorFrame.locator('#drop-zone')).toHaveClass(/hidden/);

    const frame = await getEditorEvalFrame(page);
    const tabs = await frame.evaluate(() =>
      Array.from(document.querySelectorAll('#tab-bar .tab-item span[aria-hidden]'))
        .map(el => el.textContent?.trim() || ''),
    );
    expect(tabs).toEqual(['fileA.tsv', 'fileB.tsv']);
  });

  test('空シートのタブに戻るとファイルを開く画面が再表示される', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A, 'fileA.tsv');
    await sendToEditor(page, 'addSheet');

    const editorFrame = getEditorFrame(page);
    // 1つ目のタブへ戻るとグリッド表示
    await sendToEditor(page, 'switchTab', 0);
    await expect(editorFrame.locator('#drop-zone')).toHaveClass(/hidden/);

    // 空シートのタブへ戻るとドロップ画面
    await sendToEditor(page, 'switchTab', 1);
    await expect(editorFrame.locator('#drop-zone')).not.toHaveClass(/hidden/);
  });
});
