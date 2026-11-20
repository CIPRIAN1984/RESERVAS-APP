import { useEffect, useMemo, useState } from 'react'
import qrcode from 'qrcode-generator'
import { Avatar, BackButton, EmptyState } from '../../components/ui'
import { useAvatarUrls } from '../../lib/avatars'
import { classTitle } from '../../lib/data'
import { addDays, hhmm, longDay } from '../../lib/dates'
import { initials } from '../../lib/logic'
import { gymCheckinCode, loadSessionAttendance, subscribeAttendance, type AttendeeRow } from '../../lib/remote'
import { useApp } from '../../lib/store'
import { useAuth } from '../auth/AuthProvider'

/** SVG del QR (generado en el propio dispositivo, sin servicios externos) */
function QrSvg({ text }: { text: string }) {
  const svg = useMemo(() => {
    const qr = qrcode(0, 'M')
    qr.addData(text)
    qr.make()
    return qr.createSvgTag({ cellSize: 8, margin: 2, scalable: true })
  }, [text])
  // El SVG lo genera la librería a partir de nuestro propio texto
  return <div className="w-full [&>svg]:h-auto [&>svg]:w-full" dangerouslySetInnerHTML={{ __html: svg }} />
}

/**
 * Modo kiosco: una tablet en la entrada muestra el QR de check-in de la sede
 * y la lista de quién va fichando en la clase en curso. También sirve para
 * imprimir el cartel.
 */
export function Kiosk() {
  const app = useApp()
  const auth = useAuth()
  const [code, setCode] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [attendance, setAttendance] = useState<AttendeeRow[]>([])

  useEffect(() => {
    if (!app.gymId) return
    gymCheckinCode(app.gymId)
      .then((c) => (c ? setCode(c) : setError('No tienes permiso para ver el código de la sede.')))
      .catch(() => setError('No se pudo cargar el código de la sede.'))
  }, [app.gymId])

  // La clase en curso o la siguiente (hoy o mañana)
  const session = [...app.sessionsOn(app.now), ...app.sessionsOn(addDays(app.now, 1))].find(
    (s) => s.status !== 'cancelled' && s.end > app.now,
  )
  const sid = session?.id

  useEffect(() => {
    if (!sid || auth.mode !== 'live') return
    let cancelled = false
    const load = () => loadSessionAttendance(sid).then((r) => !cancelled && setAttendance(r)).catch(() => undefined)
    void load()
    const unsub = subscribeAttendance(sid, () => void load())
    return () => {
      cancelled = true
      unsub()
    }
  }, [sid, auth.mode, app.syncVersion])

  const urls = useAvatarUrls(attendance.map((a) => a.avatarPath))

  if (auth.mode === 'demo') {
    return (
      <div className="flex flex-col gap-4 p-5 pt-14">
        <BackButton label="Volver" to="/staff/mas" />
        <EmptyState title="Kiosco no disponible en modo demo" text="El kiosco muestra el QR real de la sede y las asistencias del servidor." />
      </div>
    )
  }

  const t = session ? app.template(session.templateId) : null
  return (
    <div className="flex min-h-dvh flex-col gap-6 bg-bg px-6 pb-8 print:p-0" style={{ paddingTop: 'calc(24px + env(safe-area-inset-top))' }}>
      <div className="flex items-center justify-between print:hidden">
        <BackButton label="Salir del kiosco" to="/staff/mas" />
        <button
          onClick={() => void document.documentElement.requestFullscreen?.().catch(() => undefined)}
          className="h-11 rounded-full border-[1.5px] border-ink bg-transparent px-4 text-[14px] font-semibold text-ink"
        >
          Pantalla completa
        </button>
      </div>

      <div className="flex flex-col items-center gap-2 text-center">
        <span className="font-mono text-[12px] font-medium uppercase tracking-[0.08em] text-muted">ITACA Jiu Jitsu</span>
        <h1 className="m-0 text-[34px] font-bold leading-[1.05] tracking-[-0.02em]">Check-in</h1>
        <p className="m-0 text-[16px] text-ink-2">Abre la app ITACA, pulsa «Check-in con QR» y apunta aquí.</p>
      </div>

      <div className="mx-auto w-full max-w-[360px] rounded-[28px] bg-white p-4 shadow-sm">
        {code ? <QrSvg text={`itaca:checkin:${code}`} /> : <div className="aspect-square w-full animate-pulse rounded-2xl bg-surface" />}
      </div>
      {code && <p className="m-0 text-center text-[13px] text-muted">Código: <b className="font-mono text-ink">{code}</b></p>}
      {error && <p role="alert" className="m-0 text-center text-[14px] text-err-fg">{error}</p>}

      <div className="mx-auto flex w-full max-w-[480px] flex-col gap-3 print:hidden">
        {session && t ? (
          <>
            <div className="flex items-baseline justify-between">
              <span className="text-[18px] font-bold">
                {classTitle(t)} · {hhmm(session.start)}
              </span>
              <span className="text-[14px] text-muted">
                {attendance.length} de {session.bookedCount ?? 0} han fichado
              </span>
            </div>
            <span className="text-[13px] text-muted">{longDay(session.start)}</span>
            <div className="flex flex-wrap gap-3" aria-live="polite">
              {attendance.map((a) => (
                <span key={a.profileId} className="flex items-center gap-2 rounded-full bg-surface py-1 pr-3 pl-1">
                  <Avatar text={initials(a.name)} size={32} tone="ink" src={a.avatarPath ? urls[a.avatarPath] : null} />
                  <span className="text-[14px] font-semibold">{a.name}</span>
                </span>
              ))}
              {attendance.length === 0 && <span className="text-[14px] text-muted">Todavía no ha fichado nadie.</span>}
            </div>
          </>
        ) : (
          <p className="m-0 text-center text-[14px] text-muted">No hay más clases hoy ni mañana.</p>
        )}
      </div>
    </div>
  )
}
