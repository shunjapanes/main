import { useState } from 'react'
import {
  FilePlus, FolderOpen, Save, SaveAll, Download, Clock, PlusSquare,
  Undo2, Redo2, Scissors, Copy, Clipboard, Filter, ArrowUpAZ, ArrowDownAZ, ALargeSmall,
  RowsIcon, Columns2, Trash2, ArrowUpFromLine, ArrowDownToLine,
  MoveUp, MoveDown, CopyPlus, AlignLeft, WrapText, PanelLeft, AlignVerticalJustifyCenter,
  Shrink, Highlighter, Layers, RefreshCw,
  Database, Link, Globe, BarChart2, BookOpen, HelpCircle, Eraser,
  ArrowLeftToLine, ArrowRightToLine, Search
} from 'lucide-react'
import RibbonGroup from './RibbonGroup'
import RibbonButton from './RibbonButton'
import { send } from '../lib/bridge'

const TABS = ['ファイル', 'ホーム', 'データ', '表示', 'ツール'] as const
type Tab = typeof TABS[number]

interface Props {
  onFocusSearch?: () => void
  onOpenFile?: () => void
}

export default function RibbonToolbar({ onFocusSearch, onOpenFile }: Props) {
  const [activeTab, setActiveTab] = useState<Tab>('ホーム')

  return (
    <div className="flex flex-col bg-[#f3f2f1] border-b border-gray-300 select-none" style={{ flexShrink: 0 }}>
      {/* Tab row */}
      <div className="flex flex-row bg-[#217346]">
        {TABS.map(tab => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-1.5 text-xs font-medium transition-colors ${
              activeTab === tab
                ? 'bg-[#f3f2f1] text-gray-800'
                : 'text-white hover:bg-[#1a5c38]'
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* Ribbon content */}
      <div className="flex flex-row items-stretch h-[72px] gap-0 overflow-x-auto overflow-y-hidden">
        {activeTab === 'ファイル' && <FileTab onOpenFile={onOpenFile} />}
        {activeTab === 'ホーム' && <HomeTab onFocusSearch={onFocusSearch} />}
        {activeTab === 'データ' && <DataTab />}
        {activeTab === '表示' && <ViewTab />}
        {activeTab === 'ツール' && <ToolsTab />}
      </div>
    </div>
  )
}

function Divider() {
  return <div className="w-px bg-gray-300 self-stretch my-1 mx-0.5 flex-shrink-0" />
}

function FileTab({ onOpenFile }: { onOpenFile?: () => void }) {
  return (
    <>
      <RibbonGroup label="新規・開く">
        <RibbonButton icon={FilePlus} label="新規" onClick={() => send('new')} />
        <RibbonButton icon={FolderOpen} label="開く" onClick={() => onOpenFile ? onOpenFile() : send('open')} />
        <RibbonButton icon={PlusSquare} label="シート追加" onClick={() => send('addSheet')} />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="保存">
        <RibbonButton icon={Save} label="上書き保存" onClick={() => send('save')} />
        <RibbonButton icon={SaveAll} label="名前を付けて保存" onClick={() => send('saveAs')} />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="エクスポート">
        <RibbonButton icon={Download} label="TSV出力" onClick={() => send('exportTsv')} title="TSVとして出力" />
        <RibbonButton icon={Download} label="CSV出力" onClick={() => send('exportCsv')} title="CSVとして出力" />
        <RibbonButton icon={Globe} label="HTML出力" onClick={() => send('exportHtml')} title="HTMLとして出力" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="履歴">
        <RibbonButton icon={Clock} label="最近のファイル" onClick={() => send('recentMenu')} />
      </RibbonGroup>
    </>
  )
}

function HomeTab({ onFocusSearch }: { onFocusSearch?: () => void }) {
  return (
    <>
      <RibbonGroup label="元に戻す">
        <RibbonButton icon={Undo2} label="元に戻す" onClick={() => send('undo')} title="元に戻す (Ctrl+Z)" />
        <RibbonButton icon={Redo2} label="やり直し" onClick={() => send('redo')} title="やり直し (Ctrl+Y)" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="クリップボード">
        <RibbonButton icon={Scissors} label="切り取り" onClick={() => send('cut')} title="切り取り (Ctrl+X)" />
        <RibbonButton icon={Copy} label="コピー" onClick={() => send('copy')} title="コピー (Ctrl+C)" />
        <RibbonButton icon={Clipboard} label="貼り付け" onClick={() => send('paste')} title="貼り付け (Ctrl+V)" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="フィルター・並べ替え">
        <RibbonButton icon={Filter} label="フィルター" onClick={() => send('toggleFilter')} title="フィルター行の表示切替" />
        <RibbonButton icon={ArrowUpAZ} label="昇順" onClick={() => send('sortAsc')} title="昇順ソート" />
        <RibbonButton icon={ArrowDownAZ} label="降順" onClick={() => send('sortDesc')} title="降順ソート" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="セル">
        <RibbonButton icon={ALargeSmall} label="列幅自動調整" onClick={() => send('autoFit')} title="全列幅を自動調整" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="検索">
        <RibbonButton icon={Search} label="検索欄へ" onClick={() => onFocusSearch?.()} title="検索入力欄にフォーカス (Ctrl+F)" />
      </RibbonGroup>
    </>
  )
}

function DataTab() {
  return (
    <>
      <RibbonGroup label="行の挿入">
        <RibbonButton icon={ArrowUpFromLine} label="上に行挿入" onClick={() => send('insertRowAbove')} title="上に行を挿入 (Alt+Shift+↑)" />
        <RibbonButton icon={ArrowDownToLine} label="下に行挿入" onClick={() => send('insertRowBelow')} title="下に行を挿入 (Ctrl+Enter)" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="列の挿入">
        <RibbonButton icon={ArrowLeftToLine} label="左に列挿入" onClick={() => send('insertColLeft')} title="左に列を挿入 (Alt+Shift+←)" />
        <RibbonButton icon={ArrowRightToLine} label="右に列挿入" onClick={() => send('insertColRight')} title="右に列を挿入 (Alt+Shift+→)" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="削除">
        <RibbonButton icon={RowsIcon} label="行を削除" onClick={() => send('deleteRows')} title="選択行を削除 (Ctrl+Shift+K)" />
        <RibbonButton icon={Columns2} label="列を削除" onClick={() => send('deleteCols')} title="選択列を削除 (Ctrl+Alt+K)" />
        <RibbonButton icon={Trash2} label="空行を削除" onClick={() => send('deleteEmptyRows')} title="空行をすべて削除" />
        <RibbonButton icon={Eraser} label="重複を削除" onClick={() => send('deleteDuplicates')} title="重複行を削除" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="行の操作">
        <RibbonButton icon={MoveUp} label="行を上に移動" onClick={() => send('moveRowUp')} title="行を上に移動 (Alt+↑)" />
        <RibbonButton icon={MoveDown} label="行を下に移動" onClick={() => send('moveRowDown')} title="行を下に移動 (Alt+↓)" />
        <RibbonButton icon={CopyPlus} label="行を複製" onClick={() => send('duplicateRow')} title="行を複製 (Ctrl+Shift+D)" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="整形">
        <RibbonButton icon={AlignLeft} label="セル整形" onClick={() => send('trimCells')} title="全セルの前後空白を削除" />
      </RibbonGroup>
    </>
  )
}

function ViewTab() {
  return (
    <>
      <RibbonGroup label="表示設定">
        <RibbonButton icon={AlignVerticalJustifyCenter} label="縦ヘッダー" onClick={() => send('toggleVertHeader')} title="縦書きヘッダー切替" />
        <RibbonButton icon={WrapText} label="セル折り返し" onClick={() => send('toggleWrap')} title="セル内折り返し切替" />
        <RibbonButton icon={PanelLeft} label="列固定" onClick={() => send('toggleFreeze')} title="選択列を固定 (Ctrl+Shift+F)" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="行・列サイズ">
        <RibbonButton icon={Shrink} label="行高さ変更" onClick={() => send('cycleRowHeight')} title="行の高さを切替" />
        <RibbonButton icon={ALargeSmall} label="テキスト縮小" onClick={() => send('toggleFitText')} title="テキストを列幅に合わせて縮小" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="強調">
        <RibbonButton icon={Highlighter} label="条件付き強調" onClick={() => send('toggleCondHL')} title="条件付きハイライト切替" />
        <RibbonButton icon={Layers} label="重複強調" onClick={() => send('dupHighlight')} title="重複行を強調表示" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="リセット">
        <RibbonButton icon={RefreshCw} label="ビューリセット" onClick={() => send('resetView')} title="ビュー設定をリセット" />
      </RibbonGroup>
    </>
  )
}

function ToolsTab() {
  return (
    <>
      <RibbonGroup label="SEJマスター">
        <RibbonButton icon={Database} label="マスター読み込み" onClick={() => send('loadSejMaster')} title="SEJマスターファイルを読み込む" />
        <RibbonButton icon={Link} label="SEJ連携切替" onClick={() => send('toggleSej')} title="SEJ連携表示を切替" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="出力・プレビュー">
        <RibbonButton icon={Globe} label="プレビュー" onClick={() => send('htmlPreview')} title="HTMLプレビューを表示" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="分析">
        <RibbonButton icon={BarChart2} label="列統計" onClick={() => send('colStats')} title="選択列の統計情報を表示" />
      </RibbonGroup>
      <Divider />
      <RibbonGroup label="設定・ヘルプ">
        <RibbonButton icon={BookOpen} label="ヘッダー辞書" onClick={() => send('dictEditor')} title="ヘッダー辞書エディタを開く" />
        <RibbonButton icon={HelpCircle} label="ヘルプ" onClick={() => send('showHelp')} title="ヘルプを表示" />
      </RibbonGroup>
    </>
  )
}
