import { type LucideIcon } from 'lucide-react'
import { focusEditor } from '../lib/bridge'

interface Props {
  icon: LucideIcon
  label: string
  onClick: () => void
  disabled?: boolean
  active?: boolean
  size?: 'normal' | 'large'
  title?: string
}

export default function RibbonButton({ icon: Icon, label, onClick, disabled, active, size = 'normal', title }: Props) {
  const base = 'flex flex-col items-center justify-center gap-0.5 rounded cursor-pointer select-none transition-colors'
  const sizeClass = size === 'large'
    ? 'min-w-[60px] max-w-[76px] h-full px-1'
    : 'min-w-[48px] max-w-[68px] h-full px-1'
  const stateClass = disabled
    ? 'opacity-40 cursor-not-allowed'
    : active
      ? 'bg-green-100 border border-green-400 text-green-800'
      : 'hover:bg-gray-200 text-gray-700'

  return (
    <button
      className={`${base} ${sizeClass} ${stateClass}`}
      onClick={disabled ? undefined : () => { onClick(); focusEditor() }}
      title={title ?? label}
      aria-label={label}
      disabled={disabled}
    >
      <Icon size={size === 'large' ? 22 : 18} strokeWidth={1.5} className="flex-shrink-0" />
      <span className="text-[9px] leading-tight text-center break-all line-clamp-2 w-full">
        {label}
      </span>
    </button>
  )
}
