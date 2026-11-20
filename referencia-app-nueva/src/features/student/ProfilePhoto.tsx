import { useRef, useState } from 'react'
import { Avatar } from '../../components/ui'
import { demoAvatarDataUrl, removeAvatar, uploadAvatar } from '../../lib/avatars'
import { initials } from '../../lib/logic'
import { useApp } from '../../lib/store'
import { useAuth } from '../auth/AuthProvider'
import { useMyAvatar } from '../auth/useMyAvatar'

/** Foto de perfil con botones para cambiarla o quitarla */
export function ProfilePhoto({ name }: { name: string }) {
  const app = useApp()
  const auth = useAuth()
  const url = useMyAvatar()
  const input = useRef<HTMLInputElement>(null)
  const [busy, setBusy] = useState(false)

  const pick = async (file: File | undefined) => {
    if (!file) return
    if (file.size > 15 * 1024 * 1024) {
      app.toast('La imagen es demasiado grande (máximo 15 MB)')
      return
    }
    setBusy(true)
    try {
      if (auth.mode === 'live') {
        if (!auth.session || !auth.profile) throw new Error('Sin sesión')
        await uploadAvatar(file, auth.session.user.id, auth.profile.id, auth.profile.avatarPath)
        auth.refreshProfile()
      } else {
        app.setDemoAvatar(await demoAvatarDataUrl(file))
      }
      app.toast('Foto actualizada')
    } catch {
      app.toast('No se pudo subir la foto. Prueba con otra imagen')
    } finally {
      setBusy(false)
      if (input.current) input.current.value = ''
    }
  }

  const remove = async () => {
    setBusy(true)
    try {
      if (auth.mode === 'live') {
        if (auth.profile?.avatarPath) await removeAvatar(auth.profile.id, auth.profile.avatarPath)
        auth.refreshProfile()
      } else {
        app.setDemoAvatar(undefined)
      }
      app.toast('Foto quitada')
    } catch {
      app.toast('No se pudo quitar la foto')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="flex flex-col items-center gap-2">
      <button
        type="button"
        onClick={() => input.current?.click()}
        disabled={busy}
        aria-label={url ? 'Cambiar foto de perfil' : 'Añadir foto de perfil'}
        className="relative rounded-full border-0 bg-transparent p-0"
      >
        <Avatar text={initials(name)} size={72} tone="ink" src={url} />
        <span
          aria-hidden="true"
          className="absolute -right-1 -bottom-1 flex h-7 w-7 items-center justify-center rounded-full border-2 border-surface bg-accent text-[16px] font-bold text-on-accent"
        >
          {busy ? '…' : '+'}
        </span>
      </button>
      <input
        ref={input}
        type="file"
        accept="image/jpeg,image/png,image/webp,image/heic,image/heif"
        className="hidden"
        onChange={(e) => void pick(e.target.files?.[0])}
      />
      {url && !busy && (
        <button type="button" onClick={() => void remove()} className="hy h-8 border-0 bg-transparent text-[12px] font-semibold text-muted underline">
          Quitar foto
        </button>
      )}
    </div>
  )
}
