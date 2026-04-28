import { useEffect, useRef, useState } from 'react'
import RibbonToolbar from './components/RibbonToolbar'
import SearchBar from './components/SearchBar'
import FileTabBar from './components/FileTabBar'
import StatusBar from './components/StatusBar'

interface Tab {
  name: string
  dirty: boolean
}

interface EditorMessage {
  type: 'status' | 'tabs' | 'position' | 'stats' | 'popup'
  url?: string
  text?: string
  tabs?: Tab[]
  activeTab?: number
  position?: string
  stats?: string
}

export default function App() {
  const iframeRef = useRef<HTMLIFrameElement>(null)
  const searchInputRef = useRef<HTMLInputElement>(null)
  const [status, setStatus] = useState('準備完了')
  const [tabs, setTabs] = useState<Tab[]>([{ name: 'Sheet1', dirty: false }])
  const [activeTab, setActiveTab] = useState(0)
  const [position, setPosition] = useState('')
  const [stats, setStats] = useState('')

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
      if (msg.type === 'popup' && msg.url) window.open(msg.url, '_blank')
    }
    window.addEventListener('message', handler)
    return () => window.removeEventListener('message', handler)
  }, [])

  return (
    <div className="flex flex-col h-full w-full overflow-hidden">
      <RibbonToolbar onFocusSearch={() => searchInputRef.current?.focus()} />
      <SearchBar inputRef={searchInputRef} />
      <iframe
        ref={iframeRef}
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
