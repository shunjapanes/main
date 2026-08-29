export interface FileTab {
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

export type EditorMessage =
  | { type: 'status'; text: string }
  | { type: 'tabs'; tabs: FileTab[]; activeTab?: number }
  | { type: 'position'; position: string }
  | { type: 'stats'; stats: string }
  | { type: 'searchCount'; count: string }
  | { type: 'clearSearch' }
  | { type: 'focusSearch' }
  | ({ type: 'stateSync' } & ToggleStates)
