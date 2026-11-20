import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { VitePWA } from 'vite-plugin-pwa'
import pkg from './package.json'

export default defineConfig({
  define: { __APP_VERSION__: JSON.stringify(pkg.version) },
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icon.svg', 'favicon.ico', 'favicon-32.png', 'apple-touch-icon.png', 'fonts/*.woff2'],
      manifest: {
        name: 'ITACA Jiu Jitsu',
        short_name: 'ITACA',
        description: 'Reservas, asistencia, cinturones e ITACA+ del gimnasio ITACA Jiu Jitsu',
        lang: 'es',
        start_url: '/',
        display: 'standalone',
        orientation: 'portrait',
        background_color: '#080808',
        theme_color: '#121212',
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      workbox: {
        // La página (index.html) NO se precachea: se pide siempre a la red y la copia
        // guardada solo se usa sin conexión. Precachearla dejaba a la app en una
        // versión vieja si el service worker se instalaba justo durante una publicación.
        globPatterns: ['**/*.{js,css,svg,png,ico,woff2}'],
        navigateFallback: null,
        cleanupOutdatedCaches: true,
        // Ver public/sw-guard.js: evita guardar la página en lugar de un archivo
        importScripts: ['sw-guard.js'],
        runtimeCaching: [
          {
            urlPattern: ({ request }) => request.mode === 'navigate',
            handler: 'NetworkFirst',
            options: { cacheName: 'itaca-paginas', networkTimeoutSeconds: 4 },
          },
        ],
      },
    }),
  ],
  test: {
    environment: 'jsdom',
    globals: true,
  },
})
