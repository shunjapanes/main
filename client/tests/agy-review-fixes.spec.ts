import { test, expect } from '@playwright/test';
import { gotoApp, getEditorFrame, getEditorEvalFrame, loadContent, sendToEditor } from './helpers';

const TSV = 'Name\tScore\nAlice\t100\nBob\t200\nCarol\t300\n';

function bigTsv(rows: number) {
  const lines = ['Name\tScore'];
  for (let i = 0; i < rows; i++) lines.push(`Row${i}\t${i}`);
  return lines.join('\n') + '\n';
}

// エディター iframe の document に keydown を直接発火する
async function pressKey(
  page: Parameters<typeof gotoApp>[0],
  key: string,
  mods: { ctrlKey?: boolean; shiftKey?: boolean } = {},
) {
  const frame = await getEditorEvalFrame(page);
  await frame.evaluate(({ key, mods }) => {
    // document.onkeydown は e.target.classList を参照するため body から発火させる
    document.body.dispatchEvent(
      new KeyboardEvent('keydown', {
        key,
        ctrlKey: !!mods.ctrlKey,
        shiftKey: !!mods.shiftKey,
        bubbles: true,
        cancelable: true,
      }),
    );
  }, { key, mods });
}

test.describe('Escape キー（セル未選択時）', () => {
  test('セル未選択でも Escape でヘルプが閉じる', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV);
    await page.waitForTimeout(300);

    const frame = await getEditorEvalFrame(page);

    // 前提: 読み込み直後はセルが未選択（state.selected === null）
    const selectedCount = await frame.evaluate(
      () => document.querySelectorAll('#tbody td.selected').length,
    );
    expect(selectedCount).toBe(0);

    await sendToEditor(page, 'showHelp');
    await page.waitForTimeout(200);
    expect(
      await frame.evaluate(() =>
        document.getElementById('manual-dialog')?.classList.contains('show'),
      ),
    ).toBe(true);

    await pressKey(page, 'Escape');
    await page.waitForTimeout(200);

    expect(
      await frame.evaluate(() =>
        document.getElementById('manual-dialog')?.classList.contains('show'),
      ),
    ).toBe(false);
  });
});

test.describe('Ctrl+Y リドゥ（CapsLock ON 相当）', () => {
  test('key が大文字 "Y" でも Redo が実行される', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV);
    await page.waitForTimeout(300);

    const editorFrame = getEditorFrame(page);
    const frame = await getEditorEvalFrame(page);
    const cell = editorFrame.locator('#tbody tr').first().locator('td').nth(1);

    // セルを編集 → undo で元に戻す
    await frame.evaluate(() => {
      const td = document
        .querySelectorAll('#tbody tr')[0]
        ?.querySelectorAll('td')[1];
      td?.dispatchEvent(new MouseEvent('dblclick', { bubbles: true, cancelable: true }));
    });
    const input = cell.locator('input');
    await input.waitFor({ state: 'visible', timeout: 5000 });
    await input.fill('Charlie');
    await input.press('Enter');
    await page.waitForTimeout(150);
    await expect(cell).toHaveText('Charlie');

    await sendToEditor(page, 'undo');
    await page.waitForTimeout(200);
    await expect(cell).toHaveText('Alice');

    // CapsLock ON 時、e.key は大文字 "Y" になる
    await pressKey(page, 'Y', { ctrlKey: true });
    await page.waitForTimeout(200);
    await expect(cell).toHaveText('Charlie');
  });
});

test.describe('仮想スクロール画面外セルの編集開始', () => {
  test('選択セルが画面外でも F2 で編集を開始できる', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, bigTsv(400));
    await page.waitForTimeout(400);

    const frame = await getEditorEvalFrame(page);

    // 300行目へ移動してから、表示だけ先頭へスクロールし直す
    await sendToEditor(page, 'gotoRow', 300);
    await page.waitForTimeout(300);
    await frame.evaluate(() => {
      const c = document.getElementById('table-container')!;
      c.scrollTop = 0;
      c.dispatchEvent(new Event('scroll'));
    });
    await page.waitForTimeout(300);

    // 前提: 選択セルは DOM 上に描画されていない
    expect(
      await frame.evaluate(() => document.querySelectorAll('#tbody td.selected').length),
    ).toBe(0);

    await pressKey(page, 'F2');
    await page.waitForTimeout(300);

    // 画面内に描画し直したうえで編集が始まっていること
    expect(
      await frame.evaluate(() => document.querySelectorAll('#tbody td.editing input').length),
    ).toBe(1);
  });
});

test.describe('フィルター適用中のセル確定', () => {
  test('Enter で確定してもカーソルが非表示行へ飛ばない', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, 'Name\tGroup\nAlice\tA\nBob\tB\nCarol\tA\nDave\tB\nEve\tA\n');
    await page.waitForTimeout(300);

    const frame = await getEditorEvalFrame(page);

    // Group 列を "A" でフィルター（Alice / Carol / Eve のみ可視）
    await sendToEditor(page, 'toggleFilter');
    await page.waitForTimeout(200);
    await frame.evaluate(() => {
      const inp = document.querySelector<HTMLInputElement>('.filter-input[data-fcol="1"]')!;
      inp.value = 'A';
      inp.dispatchEvent(new Event('input', { bubbles: true }));
    });
    await page.waitForTimeout(400);

    const visibleRows = await frame.evaluate(
      () => document.querySelectorAll('#tbody tr[data-row]').length,
    );
    expect(visibleRows).toBe(3);

    // 可視行の 1 行目（データ行 0）を編集して Enter で確定
    const editorFrame = getEditorFrame(page);
    await frame.evaluate(() => {
      const td = document
        .querySelectorAll('#tbody tr[data-row]')[0]
        ?.querySelectorAll('td')[1];
      td?.dispatchEvent(new MouseEvent('dblclick', { bubbles: true, cancelable: true }));
    });
    const input = editorFrame.locator('#tbody td.editing input');
    await input.waitFor({ state: 'visible', timeout: 5000 });
    await input.fill('A');
    await input.press('Enter');
    await page.waitForTimeout(300);

    // 確定後のカーソルは可視行（＝次の可視行 Carol）にあること。
    // 修正前は物理行 1 (Bob / フィルター除外) へ飛び、選択セルが描画されなかった。
    const after = await frame.evaluate(() => {
      const td = document.querySelector('#tbody td.selected');
      const tr = td?.closest('tr');
      return { selectedCount: document.querySelectorAll('#tbody td.selected').length, row: tr?.getAttribute('data-row') ?? null };
    });
    expect(after.selectedCount).toBe(1);
    expect(after.row).toBe('2');
  });
});
