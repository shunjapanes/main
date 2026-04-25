interface Props {
  status: string
  position: string
  stats: string
}

export default function StatusBar({ status, position, stats }: Props) {
  return (
    <div
      className="flex flex-row items-center justify-between px-3 text-[11px] text-white bg-[#217346] border-t border-green-700"
      style={{ flexShrink: 0, height: 22 }}
    >
      <span className="truncate max-w-[60%]">{status || ' '}</span>
      <div className="flex items-center gap-4 flex-shrink-0">
        {stats && <span className="text-green-200">{stats}</span>}
        {position && <span>{position}</span>}
      </div>
    </div>
  )
}
