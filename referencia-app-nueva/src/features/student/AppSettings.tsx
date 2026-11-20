import { Screen } from '../../components/Layout'
import { useEffect, useState } from 'react'
import { BackButton, Btn, Card, Eyebrow, Title, cx } from '../../components/ui'
import { supabase } from '../../lib/supabase'
import { useApp } from '../../lib/store'
import { useThemePref, type ThemePref } from '../../lib/theme'
import { useAuth } from '../auth/AuthProvider'

const OPTIONS: { id: ThemePref; label: string; hint: string }[] = [
  { id: 'dark', label: 'Oscuro', hint: 'Recomendado' },
  { id: 'light', label: 'Claro', hint: '' },
  { id: 'system', label: 'Como el sistema', hint: 'Cambia con el móvil' },
]

/** Ajustes de la app: tema (por dispositivo), privacidad y versión */
export function AppSettings() {
  const [pref, setPref] = useThemePref()
  const app = useApp()
  const auth = useAuth()
  const live = auth.mode === 'live'

  const exportData = () => {
    const me = app.me
    const mine = {
      perfil: live ? auth.profile : me,
      correo: auth.session?.user.email,
      reservas: app.state.bookings.filter((b) => b.profileId === me.id),
      asistencia: app.state.attendance.filter((a) => a.profileId === me.id),
      exportado: new Date().toISOString(),
    }
    const blob = new Blob([JSON.stringify(mine, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'itaca-mis-datos.json'
    a.click()
    URL.revokeObjectURL(url)
  }
  return (
    <Screen top={24} gap={18}>
      <div className="flex items-center gap-2">
        <BackButton label="Volver al perfil" to="/perfil" />
        <Title size={44}>Ajustes de la app</Title>
      </div>

      <Card className="gap-3 p-4">
        <Eyebrow>Tema</Eyebrow>
        <div role="radiogroup" aria-label="Tema" className="grid grid-cols-3 gap-2 rounded-[14px] bg-surface-2 p-1">
          {OPTIONS.map((o) => (
            <button
              key={o.id}
              type="button"
              role="radio"
              aria-checked={pref === o.id}
              onClick={() => setPref(o.id)}
              className={cx(
                'hy flex h-12 flex-col items-center justify-center rounded-[10px] border-0 text-[14px]',
                pref === o.id ? 'bg-ink font-semibold text-on-ink' : 'bg-transparent font-medium text-ink-2',
              )}
            >
              {o.label}
            </button>
          ))}
        </div>
        <p className="m-0 text-[13px] text-muted">{OPTIONS.find((o) => o.id === pref)?.hint || 'Fondo blanco y botones negros.'}</p>
      </Card>

      <Card className="gap-3 p-4">
        <Eyebrow>Privacidad</Eyebrow>
        {live && <RankingToggle />}
        <p className="m-0 text-[14px] text-ink-2">Descarga una copia de tus datos cuando quieras. Para borrarlos, elimina tu cuenta en Configuración de la cuenta.</p>
        <div className="flex flex-wrap gap-2">
          <Btn size="sm" variant="soft" onClick={exportData}>
            Exportar mis datos
          </Btn>
          {!live && (
            <Btn
              size="sm"
              variant="ghost"
              onClick={() => {
                app.reset()
                app.toast('Datos de ejemplo restablecidos')
              }}
            >
              Restablecer datos de ejemplo
            </Btn>
          )}
        </div>
      </Card>

      <p className="m-0 text-center font-mono text-[11px] text-muted">ITACA Jiu Jitsu · versión {__APP_VERSION__}</p>
    </Screen>
  )
}

/** Aparecer o no en el ranking de Estadísticas */
function RankingToggle() {
  const app = useApp()
  const auth = useAuth()
  const id = auth.profile?.id
  const [shown, setShown] = useState<boolean | null>(null)
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    if (!supabase || !id) return
    supabase
      .from('profiles')
      .select('hide_from_ranking')
      .eq('id', id)
      .single()
      .then(({ data }) => setShown(data ? !data.hide_from_ranking : true))
  }, [id])

  const toggle = async () => {
    if (!supabase || !id || shown === null) return
    setBusy(true)
    const next = !shown
    const { error } = await supabase.from('profiles').update({ hide_from_ranking: !next }).eq('id', id)
    setBusy(false)
    if (error) return app.toast('No se pudo guardar')
    setShown(next)
    app.toast(next ? 'Vuelves a aparecer en el ranking' : 'Ya no apareces en el ranking')
  }

  return (
    <div className="flex items-center justify-between gap-4 border-b border-line pb-3">
      <span className="flex flex-col">
        <span className="text-[15px] font-medium">Aparecer en el ranking</span>
        <span className="text-[13px] text-muted">Tu nombre, foto, cinturón y clases en Estadísticas</span>
      </span>
      <button
        type="button"
        role="switch"
        aria-checked={!!shown}
        aria-label="Aparecer en el ranking"
        disabled={shown === null || busy}
        onClick={() => void toggle()}
        className={cx('relative h-8 w-14 shrink-0 rounded-full border-0 transition-colors disabled:opacity-50', shown ? 'bg-accent' : 'bg-surface-2')}
      >
        <span className={cx('absolute top-1 h-6 w-6 rounded-full bg-white shadow transition-[left]', shown ? 'left-7' : 'left-1')} />
      </button>
    </div>
  )
}
