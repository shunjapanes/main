import type { Page, FrameLocator } from '@playwright/test';

export function getEditorFrame(page: Page): FrameLocator {
  return page.frameLocator('iframe#editor-frame');
}

export async function getEditorEvalFrame(page: Page) {
  await page.waitForFunction(() => {
    const iframe = document.getElementById('editor-frame') as HTMLIFrameElement;
    return iframe?.contentDocument?.readyState === 'complete';
  });
  return page.frames().find(f => f.url().includes('editor.html'))!;
}

export async function sendToEditor(page: Page, action: string, payload?: unknown) {
  await page.evaluate(({ action, payload }) => {
    const iframe = document.getElementById('editor-frame') as HTMLIFrameElement;
    iframe?.contentWindow?.postMessage({ action, payload }, '*');
  }, { action, payload });
}

export async function loadContent(page: Page, content: string, filename = 'test.tsv') {
  const editorFrame = getEditorFrame(page);
  await sendToEditor(page, 'openContent', { content, filename });
  await editorFrame.locator('#tbody tr').first().waitFor({ timeout: 10000 });
}

export async function gotoApp(page: Page) {
  await page.goto('/main/');
  // wait for iframe to load editor.html (table exists but may be hidden before data loads)
  const editorFrame = getEditorFrame(page);
  await editorFrame.locator('#main-table').waitFor({ state: 'attached', timeout: 15000 });
}
