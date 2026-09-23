import { test, expect } from '@playwright/test';
import { gotoApp, getEditorEvalFrame, loadContent, sendToEditor } from './helpers';

// editor.html のトップレベル宣言（frame.evaluate 内でだけ参照する）
declare const state: any;
declare function pasteFromClipboard(): Promise<void>;

// Excelからコピーした表（見出し行つき）を丸ごと貼り付ける想定のクリップボード内容
const CLIP = 'seat_type_area_cd\tseat_type_area_disp_nm\tprice\r\nSF1GPE27011\tS席\t50000\r\nSF1GPE27021\tA席\t30000\r\n';

async function mockClipboard(page: Parameters<typeof gotoApp>[0], text: string) {
  const frame = await getEditorEvalFrame(page);
  await frame.evaluate((t) => {
    Object.defineProperty(navigator, 'clipboard', {
      value: { readText: async () => t, writeText: async () => {} },
      configurable: true,
    });
  }, text);
  return frame;
}

async function sheetState(frame: Awaited<ReturnType<typeof getEditorEvalFrame>>) {
  return frame.evaluate(() => {
    const s = state;
    return {
      tabs: s.tabs.length,
      headers: s.headers.join('|'),
      display: (s.displayHeaders || []).join('|'),
      rows: s.data.length,
      row0: s.data[0].join('|'),
      dirty: s.dirty,
    };
  });
}

test.describe('新しいシートへの丸ごと貼り付け', () => {
  test('＋直後（セル未選択）でも貼り付けられ、1行目がヘッダーになって日本語変換される', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, 'a\tb\tc\n1\t2\t3\n');
    await sendToEditor(page, 'addSheet');
    await page.waitForTimeout(200);
    const frame = await mockClipboard(page, CLIP);
    const before = await sheetState(frame);

    await frame.evaluate(() => pasteFromClipboard());
    await page.waitForTimeout(200);

    const after = await sheetState(frame);
    expect(after.tabs).toBe(before.tabs); // タブは増えない
    expect(after.headers).toBe('seat_type_area_cd|seat_type_area_disp_nm|price');
    expect(after.display).toContain('席種エリアコード');
    expect(after.rows).toBe(2);
    expect(after.row0).toBe('SF1GPE27011|S席|50000');
    expect(after.dirty).toBe(true); // 未保存扱い
  });

  test('データのあるシートでは従来どおり選択セルから上書き貼り付け', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, 'a\tb\tc\n1\t2\t3\n4\t5\t6\n');
    const frame = await mockClipboard(page, 'x\ty\tz\n');
    await frame.evaluate(() => {
      const s = state;
      s.selected = { row: 1, col: 0 };
      s.anchor = { row: 1, col: 0 };
      return pasteFromClipboard();
    });
    await page.waitForTimeout(200);

    const after = await sheetState(frame);
    expect(after.headers).toBe('a|b|c');
    expect(after.rows).toBe(2);
    const row1 = await frame.evaluate(() => state.data[1].join('|'));
    expect(row1).toBe('x|y|z');
  });
});
