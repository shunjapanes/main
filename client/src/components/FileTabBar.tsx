import { Plus, X } from 'lucide-react'
import { send } from '../lib/bridge'

interface Tab {
  name: string
  dirty: boolean
}

interface Props {
  tabs: Tab[]
  activeTab: number
}

export default function FileTabBar({ tabs, activeTab }: Props) {
  return (
    <div className="flex flex-row items-center bg-[#217346] overflow-x-auto overflow-y-hidden" style={{ flexShrink: 0, height: 28 }}>
      {tabs.map((tab, i) => (
        <div
          key={i}
          className={`flex items-center gap-1 px-3 cursor-pointer text-xs whitespace-nowrap border-r border-green-700 transition-colors group h-full ${
            i === activeTab
              ? 'bg-white text-gray-800 font-medium'
              : 'text-green-100 hover:bg-green-700'
          }`}
          onClick={() => send('switchTab', i)}
        >
          <span>{tab.dirty ? '● ' : ''}{tab.name}</span>
          <button
            className="opacity-0 group-hover:opacity-60 hover:!opacity-100 ml-1 rounded"
            onClick={e => { e.stopPropagation(); send('closeTab', i) }}
            title="タブを閉じる"
          >
            <X size={10} />
          </button>
        </div>
      ))}
      <button
        className="flex items-center px-2 text-green-200 hover:bg-green-700 h-full"
        onClick={() => send('addSheet')}
        title="シートを追加"
      >
        <Plus size={14} />
      </button>
    </div>
  )
}
