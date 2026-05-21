import { test, expect } from '@playwright/test';
import { gotoApp, getEditorFrame } from './helpers';

test.describe('スモークテスト', () => {
  test('ページが起動してリボンとエディターが表示される', async ({ page }) => {
    await gotoApp(page);

    // リボンのタブが表示されていること（「ファイル」タブ）
    await expect(page.getByRole('button', { name: 'ファイル' })).toBeVisible();

    // iframeのメインテーブルがDOMに存在すること（データロード前は非表示）
    const editorFrame = getEditorFrame(page);
    await expect(editorFrame.locator('#main-table')).toBeAttached();
  });

  test('リボンの全タブが表示されている', async ({ page }) => {
    await gotoApp(page);

    for (const tabName of ['ファイル', 'ホーム', 'データ', '表示', 'ツール']) {
      await expect(page.getByRole('button', { name: tabName })).toBeVisible();
    }
  });
});
