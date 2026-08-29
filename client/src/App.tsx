import { useCallback, useEffect, useRef, useState } from 'react'
import RibbonToolbar from './components/RibbonToolbar'
import SearchBar from './components/SearchBar'
import FileTabBar from './components/FileTabBar'
import StatusBar from './components/StatusBar'
import { send, focusEditor } from './lib/bridge'
import type { FileTab, ToggleStates, EditorMessage } from './types'

const DEFAULT_TOGGLES: ToggleStates = {
  filterActive: false,
  wrapActive: false,
  verticalHeaderActive: true,
  condHLActive: false,
  fitTextActive: false,
  freezeActive: false,
}

const MAX_FILE_SIZE = 100 * 1024 * 1024 // 100MB

function decodeFileContent(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  if (bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
    return new TextDecoder('utf-8').decode(bytes.subarray(3))
  }
  if (bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xfe) {
    return new TextDecoder('utf-16le').decode(bytes.subarray(2))
  }
  if (bytes.length >= 2 && bytes[0] === 0xfe && bytes[1] === 0xff) {
    return new TextDecoder('utf-16be').decode(bytes.subarray(2))
  }
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes)
  } catch {
    // not valid UTF-8 — fall through to legacy Japanese encodings
  }
  try {
    return new TextDecoder('shift_jis', { fatal: true }).decode(bytes)
  } catch {
    // fall through
  }
  try {
    return new TextDecoder('euc-jp', { fatal: true }).decode(bytes)
  } catch {
    return new TextDecoder('utf-8').decode(bytes) // last resort, lossy
  }
}

export default function App() {
  const searchInputRef = useRef<HTMLInputElement>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [status, setStatus] = useState('準備完了')
  const [tabs, setTabs] = useState<FileTab[]>([])
  const [activeTab, setActiveTab] = useState(0)
  const [position, setPosition] = useState('')
  const [stats, setStats] = useState('')
  const [searchCount, setSearchCount] = useState('')
  const [searchQuery, setSearchQuery] = useState('')
  const [toggles, setToggles] = useState<ToggleStates>(DEFAULT_TOGGLES)

  // 親フレーム（リボン）にフォーカスがある時も Cmd+Z/Y をエディタに転送
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const cmd = e.ctrlKey || e.metaKey
      if (!cmd) return
      const tag = (document.activeElement as HTMLElement)?.tagName
      // iframe自身・検索/行入力欄にフォーカスがある場合はブラウザ標準の undo/redo に任せる
      if (tag === 'IFRAME' || tag === 'INPUT' || tag === 'TEXTAREA') return
      if (e.key === 'z' || e.key === 'Z') {
        e.preventDefault()
        send(e.shiftKey ? 'redo' : 'undo')
      } else if (e.key === 'y' || e.key === 'Y') {
        e.preventDefault(); send('redo')
      }
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [])

  useEffect(() => {
    const handler = (e: MessageEvent<EditorMessage>) => {
      if (e.origin !== window.location.origin) return
      if (!e.data || typeof e.data !== 'object') return
      const msg = e.data
      switch (msg.type) {
        case 'status':
          setStatus(msg.text)
          break
        case 'tabs':
          setTabs(msg.tabs)
          if (msg.activeTab !== undefined) setActiveTab(msg.activeTab)
          break
        case 'position':
          setPosition(msg.position)
          break
        case 'stats':
          setStats(msg.stats)
          break
        case 'searchCount':
          setSearchCount(msg.count)
          break
        case 'clearSearch':
          setSearchQuery('')
          setSearchCount('')
          break
        case 'focusSearch':
          searchInputRef.current?.focus()
          break
        case 'stateSync':
          setToggles({
            filterActive: msg.filterActive,
            wrapActive: msg.wrapActive,
            verticalHeaderActive: msg.verticalHeaderActive,
            condHLActive: msg.condHLActive,
            fitTextActive: msg.fitTextActive,
            freezeActive: msg.freezeActive,
          })
          break
      }
    }
    window.addEventListener('message', handler)
    return () => window.removeEventListener('message', handler)
  }, [])

  const handleFileSelected = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (file.size > MAX_FILE_SIZE) {
      setStatus('ファイルが大きすぎます (上限100MB)')
      e.target.value = ''
      return
    }
    const reader = new FileReader()
    reader.onload = (ev) => {
      const result = ev.target?.result
      if (!(result instanceof ArrayBuffer)) return
      const content = decodeFileContent(result)
      const filename = file.name.replace(/[<>&"']/g, '_')
      send('openContent', { content, filename })
      focusEditor()
    }
    reader.onerror = () => setStatus('ファイル読み込みエラー')
    reader.readAsArrayBuffer(file)
    e.target.value = ''
  }, [])

  const handleOpenFile = useCallback(() => {
    fileInputRef.current?.click()
  }, [])

  return (
    <div className="flex flex-col h-full w-full overflow-hidden">
      <input
        ref={fileInputRef}
        type="file"
        accept=".tsv,.csv,.txt,text/plain"
        style={{ display: 'none' }}
        onChange={handleFileSelected}
      />
      <RibbonToolbar
        onFocusSearch={() => searchInputRef.current?.focus()}
        onOpenFile={handleOpenFile}
        toggleStates={toggles}
      />
      <SearchBar
        inputRef={searchInputRef}
        searchCount={searchCount}
        searchQuery={searchQuery}
        onSearchQueryChange={setSearchQuery}
      />
      <iframe
        id="editor-frame"
        src={`${import.meta.env.BASE_URL}editor.html`}
        className="flex-1 w-full border-none"
        title="TSV/CSV エディタ"
        sandbox="allow-scripts allow-same-origin allow-downloads allow-popups allow-modals"
        allow="clipboard-read; clipboard-write"
      />
      <FileTabBar tabs={tabs} activeTab={activeTab} />
      <StatusBar status={status} position={position} stats={stats} />
    </div>
  )
}
