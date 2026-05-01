# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TSV/CSV Editor — a browser-based spreadsheet editor for TSV/CSV files with an Excel-like ribbon UI, deployed as a GitHub Pages site. The UI language is Japanese.

## Commands

All commands must be run from the `client/` directory:

```bash
cd client
npm install       # install dependencies
npm run dev       # dev server at http://localhost:5173/main/
npm run build     # tsc -b && vite build (outputs to client/dist/)
npm run preview   # preview the production build locally
```

There is no test framework configured in this project.

## Architecture

The app has a strict two-layer architecture separated by an iframe boundary:

### Layer 1 — React Shell (`client/src/`)

A thin React 19 + TypeScript + Tailwind CSS app that renders the surrounding chrome:

- **`App.tsx`** — root component; embeds the editor iframe and listens for `postMessage` events from it to update React state (status text, tab list, cursor position, stats)
- **`components/RibbonToolbar.tsx`** — Excel-style ribbon with 5 tabs (ファイル, ホーム, データ, 表示, ツール); each button calls `send()` from the bridge
- **`components/SearchBar.tsx`** — search/replace bar and row-jump input; dispatches search actions via the bridge
- **`components/FileTabBar.tsx`** — sheet tabs rendered from state pushed by the editor; clicks send `switchTab`/`closeTab` actions
- **`components/StatusBar.tsx`** — displays status text, cursor position, and selection stats
- **`lib/bridge.ts`** — single exported `send(action, payload?)` function that `postMessage`s to the iframe

### Layer 2 — Vanilla JS Editor (`client/public/editor.html`)

A large (~300 KB) self-contained vanilla JS file that implements the entire grid/editor engine. It has no build step — it is copied verbatim to the `gh-pages` branch on deploy.

The bottom of `editor.html` contains an injected bridge script (inside an IIFE) that:
1. Listens for `{ action, payload }` messages from the parent and dispatches them to editor functions
2. Monkey-patches `setStatus`, `updateStatusPos`, and `renderTabBar` to forward state upward via `postMessage`

### postMessage Protocol

**React → editor** (via `bridge.ts`):
```ts
{ action: string, payload?: unknown }
```
All valid action strings are defined in the dispatch table at the bottom of `editor.html` (line ~8153).

**Editor → React** (received in `App.tsx`):
```ts
{ type: 'status',   text: string }
{ type: 'tabs',     tabs: Tab[], activeTab: number }
{ type: 'position', position: string }        // e.g. "R3 C5"
{ type: 'stats',    stats: string }
```

## Deployment

On every push to `main`, the GitHub Actions workflow (`.github/workflows/deploy.yml`):
1. Builds the React shell with `npm ci && npm run build`
2. Checks out the `gh-pages` branch and copies `client/dist/index.html`, `client/dist/assets/`, and `client/public/editor.html` into it
3. Commits and pushes — the site is served from `gh-pages`

The Vite base URL is `/main/` (matching the GitHub Pages repo path). When adding static assets they must be placed in `client/public/` to be served correctly both in dev and from `gh-pages`.

## Key Conventions

- **Adding a ribbon action**: (1) add a `RibbonButton` call in `RibbonToolbar.tsx` with `onClick={() => send('actionName')}`, (2) add the corresponding entry in the dispatch table in `editor.html`, (3) implement the editor function in the vanilla JS body of `editor.html`.
- **Editor state** is entirely within `editor.html`; the React shell only holds a mirror of what the editor pushes up via `postMessage`. Never try to read editor state directly from React.
- **`editor.html` is not bundled** — avoid adding ES module syntax or modern JS that might break older targets; keep it compatible with the existing vanilla JS style in that file.
- **Tailwind CSS** is used in the React shell only; `editor.html` uses plain CSS custom properties defined at the top of its `<style>` block.
