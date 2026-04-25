export function send(action: string, payload?: unknown): void {
  const iframe = document.getElementById('editor-frame') as HTMLIFrameElement | null
  iframe?.contentWindow?.postMessage({ action, payload }, '*')
}
