import { useRef, useState, type FormEvent } from 'react'
import { Btn, Sheet } from '../../components/ui'
import { IconCheck, IconQr } from '../../components/icons'
import { ME_ID, classTitle } from '../../lib/data'
import { hhmm, mediumDay } from '../../lib/dates'
import { checkInOpensAt, checkInWindow, isPresent } from '../../lib/logic'
import { useApp } from '../../lib/store'
import type { Session } from '../../lib/types'
import { useAuth } from '../auth/AuthProvider'
import { beep, parseCheckinQr, QrScanner } from './QrScanner'

interface Done {
  session: Session | null
  /** Guardado en el móvil: se enviará al volver la cobertura */
  queued?: boolean
}

/**
 * Check-in con QR.
 * - Modo real: la cámara lee el cartel de la entrada y el servidor elige la clase
 *   (con reserva, o la abierta con plaza). Sin cobertura, queda en cola.
 * - Modo demo: se simula la lectura aplicando la misma ventana de horario.
 */
export function useCheckIn() {
  const app = useApp()
  const auth = useAuth()
  const live = auth.mode === 'live'
  const [session, setSession] = useState<Session | null>(null)
  const [open, setOpen] = useState(false)
  const [done, setDone] = useState<Done | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [manual, setManual] = useState('')
  const handled = useRef(false)

  /** En modo real la sesión es opcional: el servidor elige la clase según el QR */
  const start = (s?: Session) => {
    setMessage(null)
    handled.current = false
    if (!s && !live) return
    if (s && !live && isPresent(app.state.attendance, s.id, ME_ID)) {
      setDone({ session: s })
      return
    }
    setSession(s ?? null)
    setOpen(true)
  }

  const close = () => {
    setOpen(false)
    setSession(null)
    setManual('')
  }

  // ---------- Modo real ----------
  const submitCode = async (code: string) => {
    if (busy) return
    setBusy(true)
    setMessage(null)
    try {
      const r = await app.checkInWithCode(code)
      if (!r.ok) {
        setMessage(r.message)
        handled.current = false
        return
      }
      beep()
      if (r.queued) setDone({ session, queued: true })
      else setDone({ session: app.sessionById(r.sessionId) ?? session })
      close()
    } finally {
      setBusy(false)
    }
  }

  const onScan = (text: string) => {
    if (handled.current) return
    const code = parseCheckinQr(text)
    if (!code) {
      setMessage('Este QR no es el de check-in de ITACA.')
      return
    }
    handled.current = true
    void submitCode(code)
  }

  const onManual = (e: FormEvent) => {
    e.preventDefault()
    const code = parseCheckinQr(manual) ?? manual.trim()
    if (code) void submitCode(code)
  }

  // ---------- Modo demo ----------
  const simulate = (force = false) => {
    if (!session) return
    const w = checkInWindow(session, app.now)
    if (w !== 'open' && !force) {
      setMessage(
        w === 'too_early'
          ? `El check-in de esta clase abre ${checkInOpensAt(session).toDateString() === app.now.toDateString() ? '' : `el ${mediumDay(session.start)} `}a las ${hhmm(checkInOpensAt(session))}.`
          : 'El check-in de esta clase ya está cerrado. Avisa a tu profesor para que te marque en la lista.',
      )
      return
    }
    app.checkIn(session)
    beep()
    setDone({ session })
    close()
  }

  const element = (
    <>
      <Sheet open={open} onClose={close} title="Check-in con QR">
        <div className="flex flex-col items-center gap-4 py-2">
          {live ? (
            <>
              <QrScanner onResult={onScan} paused={busy} />
              <p className="m-0 text-center text-[14px] text-muted">Apunta al cartel QR de la entrada o a la pantalla de recepción.</p>
            </>
          ) : (
            <>
              <div className="relative flex h-56 w-56 items-center justify-center rounded-[28px] bg-ink text-on-ink">
                <IconQr size={72} strokeWidth={1.5} />
                <span className="absolute inset-4 rounded-2xl border-2 border-dashed border-accent" />
              </div>
              <p className="m-0 text-center text-[14px] text-muted">Modo demo: la lectura con cámara funciona con el servidor; aquí se simula.</p>
            </>
          )}
          {message && (
            <p role="alert" className="m-0 w-full rounded-2xl bg-warn-bg px-4 py-3 text-[14px] font-medium text-warn-fg">
              {message}
            </p>
          )}
          {busy && <p className="m-0 text-[14px] text-muted" role="status">Fichando…</p>}
          {live ? (
            <form onSubmit={onManual} className="flex w-full flex-col gap-2">
              <label htmlFor="codigo" className="text-[12px] font-semibold text-muted">
                ¿No funciona la cámara? Escribe el código que aparece bajo el QR
              </label>
              <div className="flex gap-2">
                <input
                  id="codigo"
                  value={manual}
                  onChange={(e) => setManual(e.target.value)}
                  autoComplete="off"
                  autoCapitalize="off"
                  className="h-12 min-w-0 flex-1 rounded-[14px] border-[1.5px] border-border bg-bg px-3 text-[15px] text-ink"
                />
                <Btn type="submit" variant="ink" disabled={busy || !manual.trim()}>
                  Fichar
                </Btn>
              </div>
            </form>
          ) : (
            <>
              <Btn variant="accent" size="lg" block onClick={() => simulate()}>
                <IconQr size={20} /> Simular lectura del QR
              </Btn>
              {message && message.includes('abre') && (
                <Btn variant="ghost" onClick={() => simulate(true)}>
                  Hacer check-in igualmente (demo)
                </Btn>
              )}
            </>
          )}
        </div>
      </Sheet>
      {done && <CheckInDone done={done} name={auth.profile?.fullName ?? app.me.name} onClose={() => setDone(null)} />}
    </>
  )

  return { start, element }
}

function CheckInDone({ done, name, onClose }: { done: Done; name: string; onClose: () => void }) {
  const app = useApp()
  const s = done.session
  const t = s ? app.template(s.templateId) : null
  return (
    <div role="dialog" aria-modal="true" aria-label="Check-in hecho" className="fixed inset-0 z-50 flex justify-center bg-accent text-on-accent">
      <div className="pt-safe pb-safe flex w-full max-w-[480px] flex-col items-center justify-center gap-6 px-8 text-center">
        <span className="flex h-28 w-28 items-center justify-center rounded-full bg-[#0A0A0A] text-[#FFE14D]">
          <IconCheck size={56} />
        </span>
        <h1 className="m-0 text-[34px] font-bold leading-[1.05] tracking-[-0.02em]">{done.queued ? 'Check-in guardado' : 'Check-in hecho'}</h1>
        <div className="flex flex-col gap-1">
          <span className="text-[22px] font-bold">{name}</span>
          {s && t && !done.queued && (
            <span className="text-[16px]">
              {classTitle(t)} · {hhmm(s.start)}
            </span>
          )}
          {done.queued && <span className="text-[16px]">Sin cobertura: se enviará en cuanto vuelva la red.</span>}
        </div>
        <button onClick={onClose} className="mt-6 h-[54px] w-full rounded-full border-0 bg-[#0A0A0A] text-[16px] font-bold text-white">
          Listo
        </button>
      </div>
    </div>
  )
}
