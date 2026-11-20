import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router'
import { registerSW } from 'virtual:pwa-register'
import { App } from './App'
import { AuthProvider } from './features/auth/AuthProvider'
import { AppProvider } from './lib/store'
import { applyTheme, watchSystemTheme } from './lib/theme'
import './styles/tokens.css'

registerSW({ immediate: true })
applyTheme()
watchSystemTheme()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <AppProvider>
          <App />
        </AppProvider>
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>,
)
