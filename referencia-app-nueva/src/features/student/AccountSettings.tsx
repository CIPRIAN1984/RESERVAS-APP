import { useState, type FormEvent } from 'react'
import { Screen } from '../../components/Layout'
import { BackButton, Btn, Card, Eyebrow, Sheet, Title } from '../../components/ui'
import { removeAvatar } from '../../lib/avatars'
import { useApp } from '../../lib/store'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../auth/AuthProvider'
import { PasswordForm } from '../auth/Login'

const inputCls = 'h-12 w-full rounded-[12px] border border-border bg-surface-2 px-3 text-[16px] text-ink'

/** Configuración de la cuenta: correo, teléfono, contraseña y eliminar cuenta */
export function AccountSettings() {
  const app = useApp()
  const auth = useAuth()
  const live = auth.mode === 'live'
  const [phone, setPhone] = useState(auth.profile?.phone ?? '')
  const [savingPhone, setSavingPhone] = useState(false)
  const [pwOpen, setPwOpen] = useState(false)
  const [delOpen, setDelOpen] = useState(false)

  const savePhone = async (e: FormEvent) => {
    e.preventDefault()
    if (!supabase || !auth.profile) return
    setSavingPhone(true)
    const { error } = await supabase.from('profiles').update({ phone: phone.trim() || null }).eq('id', auth.profile.id)
    setSavingPhone(false)
    if (error) app.toast('No se pudo guardar el teléfono')
    else {
      auth.refreshProfile()
      app.toast('Teléfono guardado')
    }
  }

  if (!live) {
    return (
      <Screen top={24} gap={18}>
        <div className="flex items-center gap-2">
          <BackButton label="Volver al perfil" to="/perfil" />
          <Title size={44}>Cuenta</Title>
        </div>
        <Card className="p-4 text-[14px] text-muted">En el modo demo no hay cuenta. Con el servidor, aquí se cambian el correo, la contraseña y se puede eliminar la cuenta.</Card>
      </Screen>
    )
  }

  return (
    <Screen top={24} gap={18}>
      <div className="flex items-center gap-2">
        <BackButton label="Volver al perfil" to="/perfil" />
        <Title size={44}>Configuración de la cuenta</Title>
      </div>

      <Card className="gap-2 p-4">
        <Eyebrow>Correo electrónico</Eyebrow>
        <span className="text-[16px] font-medium">{auth.session?.user.email}</span>
        <span className="text-[12px] text-muted">Es tu usuario para entrar. Para cambiarlo, pídelo en recepción.</span>
      </Card>

      <Card className="gap-3 p-4">
        <Eyebrow>Número de teléfono</Eyebrow>
        <form onSubmit={savePhone} className="flex gap-2">
          <input
            className={inputCls}
            type="tel"
            autoComplete="tel"
            maxLength={30}
            placeholder="Añade tu móvil"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            aria-label="Número de teléfono"
          />
          <Btn type="submit" variant="soft" disabled={savingPhone || phone === (auth.profile?.phone ?? '')}>
            Guardar
          </Btn>
        </form>
      </Card>

      <Card className="gap-3 p-4">
        <Eyebrow>Contraseña</Eyebrow>
        <p className="m-0 text-[14px] text-ink-2">Con una contraseña puedes entrar sin esperar el correo con el enlace.</p>
        <Btn variant="soft" block onClick={() => setPwOpen(true)}>
          Crear o cambiar contraseña
        </Btn>
      </Card>

      <button
        type="button"
        onClick={() => setDelOpen(true)}
        className="self-start border-0 bg-transparent px-0 py-2 text-[15px] font-semibold text-err-fg"
      >
        Eliminar cuenta
      </button>

      <Sheet open={pwOpen} onClose={() => setPwOpen(false)} title="Contraseña">
        <PasswordForm
          onDone={() => {
            setPwOpen(false)
            app.toast('Contraseña guardada. Ya puedes entrar con ella')
          }}
        />
      </Sheet>
      {delOpen && <DeleteAccountSheet onClose={() => setDelOpen(false)} />}
    </Screen>
  )
}

function DeleteAccountSheet({ onClose }: { onClose: () => void }) {
  const app = useApp()
  const auth = useAuth()
  const [confirm, setConfirm] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const del = async () => {
    if (!supabase || !auth.profile) return
    setBusy(true)
    setError('')
    try {
      if (auth.profile.avatarPath) await removeAvatar(auth.profile.id, auth.profile.avatarPath).catch(() => undefined)
      const { error } = await supabase.rpc('delete_my_account')
      if (error) throw error
      await supabase.auth.signOut()
      app.toast('Tu cuenta se ha eliminado')
    } catch (e) {
      const err = e as { message?: string; hint?: string }
      setError(err.hint === 'last_owner' ? 'Eres el único propietario del gimnasio: nombra antes a otro propietario.' : 'No se pudo eliminar la cuenta. Inténtalo de nuevo.')
      setBusy(false)
    }
  }

  return (
    <Sheet open onClose={onClose} title="Eliminar cuenta">
      <p className="m-0 text-[14px] text-ink-2">
        Se borran tu acceso, tu nombre, tu foto y tus datos de contacto, y se cancelan tus reservas futuras. Tu asistencia pasada se conserva sin tu nombre para las estadísticas del gimnasio. <b>No se puede deshacer.</b>
      </p>
      <label className="flex flex-col gap-2 text-[13px] font-medium text-ink-2">
        Escribe ELIMINAR para confirmar
        <input className={inputCls} value={confirm} onChange={(e) => setConfirm(e.target.value)} autoCapitalize="characters" />
      </label>
      {error && (
        <p role="alert" className="m-0 rounded-[12px] bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
          {error}
        </p>
      )}
      <button
        type="button"
        disabled={confirm.trim().toUpperCase() !== 'ELIMINAR' || busy}
        onClick={() => void del()}
        className="h-12 rounded-[12px] border-0 bg-err-fg text-[15px] font-semibold text-bg disabled:opacity-40"
      >
        {busy ? 'Eliminando…' : 'Eliminar mi cuenta'}
      </button>
    </Sheet>
  )
}
