import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    VitePWA({
            registerType: 'autoUpdate',
      manifest: {
        name: 'Web Monitoring GlucoBand',
        short_name: 'GlucoBand',
        description: 'Aplikasi untuk memantau riwayat pemeriksaan pasien.',
        theme_color: '#007bff',
        background_color: '#f0f2f5',
        display: 'standalone',
        scope: '/',
        start_url: '/',
        icons: [
          { src: '/pwa-192x192.png', sizes: '192x192', type: 'image/png' },
          { src: '/pwa-512x512.png', sizes: '512x512', type: 'image/png' },
        ],
      }
    })
  ],
})
