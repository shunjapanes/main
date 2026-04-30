import { useCallback, useEffect, useRef, useState } from 'react'
import RibbonToolbar from './components/RibbonToolbar'
import SearchBar from './components/SearchBar'
import FileTabBar from './components/FileTabBar'
import StatusBar from './components/StatusBar'
import { send, focusEditor } from './lib/bridge'

interface Tab {
  name: string
  dirty: boolean
}

export interface ToggleStates {
  filterActive: boolean
  wrapActive: boolean
  verticalHeaderActive: boolean
  condHLActive: boolean
  fitTextActive: boolean
  freezeActive: boolean
}

interface EditorMessage {
  type: 'status' | 'tabs' | 'position' | 'stats' | 'searchCount' | 'clearSearch' | 'focusSearch' | 'stateSync'
  text?: string
  tabs?: Tab[]
  activeTab?: number
  position?: string
  stats?: string
  count?: string
  filterActive?: boolean
  wrapActive?: boolean
  verticalHeaderActive?: boolean
  condHLActive?: boolean
  fitTextActive?: boolean
  freezeActive?: boolean
}

const DEFAULT_TOGGLES: ToggleStates = {
  filterActive: false,
  wrapActive: false,
  verticalHeaderActive: true,
  condHLActive: false,
  fitTextActive: false,
  freezeActive: false,
}

export default function App() {
  const searchInputRef = useRef<HTMLInputElement>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [status, setStatus] = useState('準備完了')
  const [tabs, setTabs] = useState<Tab[]>([])
  const [activeTab, setActiveTab] = useState(0)
  const [position, setPosition] = useState('')
  const [stats, setStats] = useState('')
  const [searchCount, setSearchCount] = useState('')
  const [searchQuery, setSearchQuery] = useState('')
  const [toggles, setToggles] = useState<ToggleStates>(DEFAULT_TOGGLES)

  useEffect(() => {
    const handler = (e: MessageEvent<EditorMessage>) => {
      if (!e.data || typeof e.data !== 'object') return
      const msg = e.data
      if (msg.type === 'status' && msg.text !== undefined) setStatus(msg.text)
      if (msg.type === 'tabs' && msg.tabs !== undefined) {
        setTabs(msg.tabs)
        if (msg.activeTab !== undefined) setActiveTab(msg.activeTab)
      }
      if (msg.type === 'position' && msg.position !== undefined) setPosition(msg.position)
      if (msg.type === 'stats' && msg.stats !== undefined) setStats(msg.stats)
      if (msg.type === 'searchCount' && msg.count !== undefined) setSearchCount(msg.count)
      if (msg.type === 'clearSearch') { setSearchQuery(''); setSearchCount('') }
      if (msg.type === 'focusSearch') searchInputRef.current?.focus()
      if (msg.type === 'stateSync') {
        setToggles({
          filterActive: !!(msg.filterActive),
          wrapActive: !!(msg.wrapActive),
          verticalHeaderActive: !!(msg.verticalHeaderActive),
          condHLActive: !!(msg.condHLActive),
          fitTextActive: !!(msg.fitTextActive),
          freezeActive: !!(msg.freezeActive),
        })
      }
    }
    window.addEventListener('message', handler)
    return () => window.removeEventListener('message', handler)
  }, [])

  const handleFileSelected = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (ev) => {
      const content = ev.target?.result as string
      if (content != null) { send('openContent', { content, filename: file.name }); focusEditor() }
    }
    reader.readAsText(file)
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
        allow="clipboard-read; clipboard-write; popups"
      />
      <FileTabBar tabs={tabs} activeTab={activeTab} />
      <StatusBar status={status} position={position} stats={stats} />
    </div>
  )
}
