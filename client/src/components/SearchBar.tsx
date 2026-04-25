import { useState } from 'react'
import { Search, Replace, Hash, ChevronDown, ChevronUp, X } from 'lucide-react'
import { send } from '../lib/bridge'

export default function SearchBar() {
  const [query, setQuery] = useState('')
  const [replaceText, setReplaceText] = useState('')
  const [showReplace, setShowReplace] = useState(false)
  const [rowNum, setRowNum] = useState('')

  const doSearch = () => {
    send('search', query)
  }

  const doGotoRow = () => {
    if (rowNum) send('gotoRow', rowNum)
  }

  return (
    <div className="flex flex-row items-center gap-1 px-2 py-1 bg-white border-b border-gray-200 text-xs" style={{ flexShrink: 0 }}>
      {/* Search */}
      <div className="flex flex-row items-center bg-gray-100 border border-gray-300 rounded overflow-hidden">
        <Search size={13} className="ml-1.5 text-gray-500 flex-shrink-0" />
        <input
          className="bg-transparent outline-none px-1.5 py-0.5 w-44 text-xs"
          placeholder="検索..."
          value={query}
          onChange={e => setQuery(e.target.value)}
          onKeyDown={e => {
            if (e.key === 'Enter') { e.shiftKey ? send('searchPrev') : send('searchNext') }
            if (e.key === 'Escape') { setQuery(''); send('clearSearch') }
          }}
        />
        {query && (
          <button className="mr-1 text-gray-400 hover:text-gray-600" onClick={() => { setQuery(''); send('clearSearch') }}>
            <X size={12} />
          </button>
        )}
      </div>

      <button className="p-1 rounded hover:bg-gray-100 text-gray-600" onClick={() => send('searchPrev')} title="前を検索 (Shift+Enter)">
        <ChevronUp size={14} />
      </button>
      <button className="p-1 rounded hover:bg-gray-100 text-gray-600" onClick={() => doSearch()} title="次を検索 (Enter)">
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
          <button className="px-2 py-0.5 rounded bg-gray-200 hover:bg-gray-300 text-xs" onClick={() => send('replaceOne', replaceText)}>1件</button>
          <button className="px-2 py-0.5 rounded bg-gray-200 hover:bg-gray-300 text-xs" onClick={() => send('replaceAll', replaceText)}>全て</button>
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
