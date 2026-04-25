import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: '/tsv-editor/',
  server: {
    port: 5173,
  },
})
