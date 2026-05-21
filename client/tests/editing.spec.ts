import { test, expect } from '@playwright/test';
import { gotoApp, getEditorFrame, getEditorEvalFrame, loadContent, sendToEditor } from './helpers';

const TSV = 'Name\tScore\nAlice\t100\nBob\t200\n';

async function editCell(page: Parameters<typeof gotoApp>[0], rowIdx: number, colIdx: number, newValue: string) {
  const editorFrame = getEditorFrame(page);
  // frame.evaluate でダブルクリックイベントを直接発火（DOM再構築の競合を避ける）
  const frame = await getEditorEvalFrame(page);
  await frame.evaluate(({ rowIdx, colIdx }) => {
    const row = document.querySelectorAll('#tbody tr')[rowIdx];
    if (!row) return;
    const td = row.querySelectorAll('td')[colIdx + 1]; // +1 for row-num column
    if (!td) return;
    td.dispatchEvent(new MouseEvent('dblclick', { bubbles: true, cancelable: true }));
  }, { rowIdx, colIdx });

  // inputが現れるのを待って値を入力
  const cell = editorFrame.locator('#tbody tr').nth(rowIdx).locator('td').nth(colIdx + 1);
  const input = cell.locator('input');
  await input.waitFor({ state: 'visible', timeout: 5000 });
  await input.fill(newValue);
  await input.press('Enter');
  await page.waitForTimeout(100);
}

test.describe('セル編集', () => {
  test('セルをダブルクリックして値を編集できる', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV);
    await page.waitForTimeout(300); // レンダリング安定待ち

    await editCell(page, 0, 0, 'Charlie');

    const editorFrame = getEditorFrame(page);
    const cell = editorFrame.locator('#tbody tr').first().locator('td').nth(1);
    await expect(cell).toHaveText('Charlie');
  });

  test('編集後にundo bridgeで元の値に戻る', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV);
    await page.waitForTimeout(300);

    await editCell(page, 0, 0, 'Charlie');

    const editorFrame = getEditorFrame(page);
    const cell = editorFrame.locator('#tbody tr').first().locator('td').nth(1);
    await expect(cell).toHaveText('Charlie');

    await sendToEditor(page, 'undo');
    await page.waitForTimeout(200);
    await expect(cell).toHaveText('Alice');
  });

  test('undoの後にredo bridgeで再適用できる', async ({ page }) => {
    await gotoApp(page);
    await loadContent(page, TSV);
    await page.waitForTimeout(300);

    await editCell(page, 0, 0, 'Charlie');

    const editorFrame = getEditorFrame(page);
    const cell = editorFrame.locator('#tbody tr').first().locator('td').nth(1);
    await expect(cell).toHaveText('Charlie');

    await sendToEditor(page, 'undo');
    await page.waitForTimeout(200);
    await expect(cell).toHaveText('Alice');

    await sendToEditor(page, 'redo');
    await page.waitForTimeout(200);
    await expect(cell).toHaveText('Charlie');
  });
});
