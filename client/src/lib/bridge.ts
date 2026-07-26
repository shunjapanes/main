export function send(action: string, payload?: unknown): void {
  const iframe = document.getElementById('editor-frame') as HTMLIFrameElement | null
  iframe?.contentWindow?.postMessage({ action, payload }, window.location.origin)
}

export function focusEditor(): void {
  try {
    const iframe = document.getElementById('editor-frame') as HTMLIFrameElement | null
    iframe?.contentWindow?.focus()
  } catch {
    // cross-origin restriction on contentWindow.focus() — safe to ignore
  }
}
