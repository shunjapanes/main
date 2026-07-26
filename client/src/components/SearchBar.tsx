import { type Ref, useEffect, useRef, useState } from 'react'
import { Search, Replace, Hash, ChevronDown, ChevronUp, X } from 'lucide-react'
import { send, focusEditor } from '../lib/bridge'

interface Props {
  inputRef?: Ref<HTMLInputElement>
  searchCount?: string
  searchQuery?: string
  onSearchQueryChange?: (q: string) => void
}

const SEARCH_DEBOUNCE_MS = 180 // typing pause before dispatching a live search to the editor
const NAV_DELAY_MS = 30 // gives the editor time to process 'search' before navigating to a match

export default function SearchBar({ inputRef, searchCount, searchQuery, onSearchQueryChange }: Props) {
  // Fully controlled by the parent — avoids the dual internal/external query state that used to require
  // a separate sync effect.
  const query = searchQuery ?? ''
  const [replaceText, setReplaceText] = useState('')
  const [showReplace, setShowReplace] = useState(false)
  const [rowNum, setRowNum] = useState('')
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const isFirstRender = useRef(true)

  useEffect(() => {
    if (isFirstRender.current) {
      isFirstRender.current = false
      return // don't fire a phantom empty search on mount
    }
    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => {
      send('search', query)
    }, SEARCH_DEBOUNCE_MS)
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current) }
  }, [query])

  const handleQueryChange = (val: string) => {
    onSearchQueryChange?.(val)
  }

  const flushDebounce = () => {
    if (debounceRef.current) { clearTimeout(debounceRef.current); debounceRef.current = null }
  }

  const flushAndNavigate = (direction: 'searchPrev' | 'searchNext') => {
    flushDebounce()
    send('search', query)
    setTimeout(() => send(direction), NAV_DELAY_MS)
  }

  const clearQuery = () => {
    flushDebounce()
    handleQueryChange('')
    send('clearSearch')
    focusEditor()
  }

  const doGotoRow = () => {
    if (rowNum) send('gotoRow', Number(rowNum))
  }

  return (
    <div className="flex flex-row items-center gap-1 px-2 py-1 bg-white border-b border-gray-200 text-xs overflow-x-auto overflow-y-hidden flex-shrink-0">
      {/* Search */}
      <div className="flex flex-row items-center bg-gray-100 border border-gray-300 rounded overflow-hidden">
        <Search size={13} className="ml-1.5 text-gray-500 flex-shrink-0" />
        <input
          ref={inputRef}
          className="bg-transparent outline-none px-1.5 py-0.5 w-44 text-xs"
          placeholder="検索..."
          value={query}
          onChange={e => { if ((e.nativeEvent as InputEvent).isComposing) return; handleQueryChange(e.target.value) }}
          onCompositionEnd={e => handleQueryChange((e.target as HTMLInputElement).value)}
          onKeyDown={e => {
            const cmd = e.ctrlKey || e.metaKey
            if (e.key === 'Enter' && !e.nativeEvent.isComposing) {
              flushAndNavigate(e.shiftKey ? 'searchPrev' : 'searchNext')
            }
            if (e.key === 'Escape') clearQuery()
            if (cmd && (e.key === 'f' || e.key === 'F')) { e.preventDefault(); (e.target as HTMLInputElement).select() }
          }}
        />
        {searchCount && <span className="mx-1 text-gray-500 text-[10px] whitespace-nowrap">{searchCount}</span>}
        {query && (
          <button className="mr-1 text-gray-400 hover:text-gray-600" onClick={clearQuery} title="検索クリア" aria-label="検索クリア">
            <X size={12} />
          </button>
        )}
      </div>

      <button className="p-1 rounded hover:bg-gray-100 text-gray-600" onClick={() => flushAndNavigate('searchPrev')} title="前を検索 (Shift+Enter)">
        <ChevronUp size={14} />
      </button>
      <button className="p-1 rounded hover:bg-gray-100 text-gray-600" onClick={() => flushAndNavigate('searchNext')} title="次を検索 (Enter)">
        <ChevronDown size={14} />
      </button>

      {/* Toggle replace */}
      <button
        className={`flex items-center gap-1 px-2 py-0.5 rounded text-xs ${showReplace ? 'bg-blue-100 text-blue-700' : 'hover:bg-gray-100 text-gray-600'}`}
        onClick={() => setShowReplace(v => !v)}
        title="置換パネルを表示"
      >
        <Replace size={13} />
        <span>置換</span>
      </button>

      {showReplace && (
        <>
          <div className="flex flex-row items-center bg-gray-100 border border-gray-300 rounded overflow-hidden">
            <Replace size={13} className="ml-1.5 text-gray-500 flex-shrink-0" />
            <input
              className="bg-transparent outline-none px-1.5 py-0.5 w-36 text-xs"
              placeholder="置換テキスト..."
              value={replaceText}
              onChange={e => setReplaceText(e.target.value)}
            />
          </div>
          <button
            className="px-2 py-0.5 rounded bg-gray-200 hover:bg-gray-300 text-xs"
            onClick={() => { flushDebounce(); send('search', query); send('replaceOne', replaceText) }}
            title="1件置換"
            aria-label="1件置換"
          >1件</button>
          <button
            className="px-2 py-0.5 rounded bg-gray-200 hover:bg-gray-300 text-xs"
            onClick={() => { flushDebounce(); send('search', query); send('replaceAll', replaceText) }}
            title="全て置換"
            aria-label="全て置換"
          >全て</button>
        </>
      )}

      <div className="w-px bg-gray-300 self-stretch mx-1" />

      {/* Row jump */}
      <div className="flex flex-row items-center gap-1">
        <Hash size={13} className="text-gray-500" />
        <input
          className="bg-gray-100 border border-gray-300 rounded outline-none px-1.5 py-0.5 w-16 text-xs"
          placeholder="行へ..."
          value={rowNum}
          onChange={e => setRowNum(e.target.value.replace(/[^0-9]/g, ''))}
          onKeyDown={e => { if (e.key === 'Enter') doGotoRow() }}
        />
        <button className="px-2 py-0.5 rounded bg-gray-200 hover:bg-gray-300 text-xs" onClick={doGotoRow}>移動</button>
      </div>
    </div>
  )
}
