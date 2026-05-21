import { test, expect } from '@playwright/test';
import { gotoApp, getEditorEvalFrame, loadContent, sendToEditor } from './helpers';

const TSV_A = 'Col1\tCol2\nA1\tA2\nA3\tA4\n';
const TSV_B = 'X\tY\nB1\tB2\nB3\tB4\n';

test.describe('新規ファイルロード時のビュー状態リセット', () => {
  test('折り返しON後に別ファイルを開くと折り返しがOFFにリセットされる', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A, 'fileA.tsv');

    // 折り返しをONにする
    await sendToEditor(page, 'toggleWrap');
    await page.waitForTimeout(200);

    const frame = await getEditorEvalFrame(page);

    // wrap-cellsクラスが付いていることを確認
    const wrapActive = await frame.evaluate(() =>
      document.body.classList.contains('wrap-cells')
    );
    expect(wrapActive).toBe(true);

    // 別ファイルを読み込む
    await sendToEditor(page, 'openContent', { content: TSV_B, filename: 'fileB.tsv' });
    await page.waitForTimeout(500);

    // wrap-cellsがリセットされていること
    const wrapAfter = await frame.evaluate(() =>
      document.body.classList.contains('wrap-cells')
    );
    expect(wrapAfter).toBe(false);

    // btn-wrapのaria-pressedもfalseになっていること
    const ariaPressed = await frame.evaluate(() =>
      document.getElementById('btn-wrap')?.getAttribute('aria-pressed')
    );
    expect(ariaPressed).toBe('false');
  });

  test('フィルター表示後に別ファイルを開くとフィルターがリセットされる', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A, 'fileA.tsv');

    // フィルターをONにする
    await sendToEditor(page, 'toggleFilter');
    await page.waitForTimeout(200);

    const frame = await getEditorEvalFrame(page);
    const filterVisible = await frame.evaluate(() => {
      const btn = document.getElementById('btn-filter-toggle');
      return btn?.getAttribute('aria-pressed') === 'true';
    });
    expect(filterVisible).toBe(true);

    // 別ファイルを読み込む
    await sendToEditor(page, 'openContent', { content: TSV_B, filename: 'fileB.tsv' });
    await page.waitForTimeout(500);

    // フィルターがリセットされていること
    const filterAfter = await frame.evaluate(() => {
      const btn = document.getElementById('btn-filter-toggle');
      return btn?.getAttribute('aria-pressed');
    });
    expect(filterAfter).toBe('false');
  });

  test('hiddenRowsとhiddenColsが新規ファイルロードでリセットされる', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV_A, 'fileA.tsv');

    const frame = await getEditorEvalFrame(page);

    // stateのhiddenRowsを直接操作（テスト用）
    await frame.evaluate(() => {
      (window as any).state?.hiddenRows?.add(0);
      (window as any).state?.hiddenCols?.add(0);
    });

    // 別ファイルを読み込む
    await sendToEditor(page, 'openContent', { content: TSV_B, filename: 'fileB.tsv' });
    await page.waitForTimeout(500);

    // hiddenRows/hiddenColsがリセットされていること
    const hiddenSizes = await frame.evaluate(() => ({
      rows: (window as any).state?.hiddenRows?.size ?? 0,
      cols: (window as any).state?.hiddenCols?.size ?? 0,
    }));
    expect(hiddenSizes.rows).toBe(0);
    expect(hiddenSizes.cols).toBe(0);
  });
});
