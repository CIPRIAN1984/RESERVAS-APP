import { useAvatarUrls } from '../../lib/avatars'
import { useApp } from '../../lib/store'
import { useAuth } from './AuthProvider'

/** Dirección de mi foto de perfil (servidor en modo real, dispositivo en modo demo) */
export function useMyAvatar(): string | null {
  const auth = useAuth()
  const app = useApp()
  const path = auth.mode === 'live' ? auth.profile?.avatarPath ?? null : null
  const urls = useAvatarUrls([path])
  if (auth.mode === 'demo') return app.state.demoAvatar ?? null
  return path ? urls[path] ?? null : null
}
