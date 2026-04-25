import type { Config } from 'tailwindcss'

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        ribbon: {
          bg: '#f3f2f1',
          tab: '#217346',
          tabHover: '#1a5c38',
          tabText: '#ffffff',
          border: '#d1d5db',
          groupLabel: '#6b7280',
          btnHover: '#e5e7eb',
          btnActive: '#d1fae5',
        },
      },
    },
  },
  plugins: [],
} satisfies Config
