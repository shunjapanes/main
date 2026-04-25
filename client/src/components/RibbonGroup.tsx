import { type ReactNode } from 'react'

interface Props {
  label: string
  children: ReactNode
}

export default function RibbonGroup({ label, children }: Props) {
  return (
    <div className="flex flex-col items-stretch h-full">
      <div className="flex flex-row items-center gap-0.5 flex-1 px-1 pt-1">
        {children}
      </div>
      <div className="text-[9px] text-gray-500 text-center border-t border-gray-300 py-0.5 px-1 leading-tight">
        {label}
      </div>
    </div>
  )
}
