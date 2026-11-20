import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router'
import { Btn, Sheet } from '../../components/ui'
import { hhmm, mediumDay } from '../../lib/dates'
import type { DbDiscipline } from '../../lib/remote'
import { useApp } from '../../lib/store'
import { supabase } from '../../lib/supabase'
import type { Session } from '../../lib/types'
import { OneOffSheet } from './ScheduleEditor'

const inputCls = 'h-12 w-full rounded-[14px] border-[1.5px] border-border bg-bg px-3 text-[15px] text-ink'
const labelCls = 'flex flex-col gap-1 text-[12px] font-semibold text-muted'

interface Row {
  capacity: number
  booked_count: number
  waitlist_count: number
  substitute_coach_profile_id: string | null
  coach_profile_id: string | null
  place: string
  status: 'scheduled' | 'cancelled' | 'done'
  cancel_reason: string | null
  cancelled_by_closure: string | null
  template_id: string | null
}

/** Gestionar la clase de un día: aforo, sustituto, lugar, cancelar o recuperar */
export function SessionAdminSheet({ session, onClose }: { session: Session; onClose: () => void }) {
  const app = useApp()
  const nav = useNavigate()
  const t = app.template(session.templateId)
  const [row, setRow] = useState<Row | null>(null)
  const [cap, setCap] = useState(0)
  const [sub, setSub] = useState('')
  const [place, setPlace] = useState('')
  const [reason, setReason] = useState('')
  const [confirmCancel, setConfirmCancel] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!supabase) return
    supabase
      .from('class_sessions')
      .select('capacity, booked_count, waitlist_count, substitute_coach_profile_id, coach_profile_id, place, status, cancel_reason, cancelled_by_closure, template_id')
      .eq('id', session.id)
      .single()
      .then(({ data }) => {
        if (!data) return
        const r = data as Row
        setRow(r)
        setCap(r.capacity)
        setSub(r.substitute_coach_profile_id ?? '')
        setPlace(r.place)
      })
  }, [session.id])

  const done = async (msg: string) => {
    await app.reloadSchedule()
    app.toast(msg)
    onClose()
  }

  const call = async (fn: string, args: Record<string, unknown>, msg: string) => {
    setBusy(true)
    setError(null)
    const { error } = await supabase!.rpc(fn, args)
    setBusy(false)
    if (error) return setError(error.code === '42501' ? 'No tienes permiso para cambiar el horario' : error.message)
    await done(msg)
  }

  const ended = session.end <= app.now
  const cancelled = row?.status === 'cancelled'
  const changed = row && (cap !== row.capacity || sub !== (row.substitute_coach_profile_id ?? '') || place.trim() !== row.place)
  const regular = app.coaches.find((c) => c.id === row?.coach_profile_id)

  return (
    <Sheet open onClose={onClose} title={t.name}>
      <p className="m-0 text-[14px] text-muted">
        {mediumDay(session.start)} · {hhmm(session.start)}–{hhmm(session.end)}
        {row ? ` · ${row.booked_count} ${row.booked_count === 1 ? 'reserva' : 'reservas'}${row.waitlist_count ? `, ${row.waitlist_count} en espera` : ''}` : ''}
      </p>

      {!row ? (
        <p className="m-0 text-[14px] text-muted">Cargando…</p>
      ) : ended ? (
        <p className="m-0 rounded-2xl bg-surface-2 px-4 py-3 text-[14px]">Esta clase ya ha terminado.</p>
      ) : cancelled ? (
        <div className="flex flex-col gap-3">
          <p className="m-0 rounded-2xl bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">Cancelada: {row.cancel_reason ?? 'sin motivo'}</p>
          {row.cancelled_by_closure ? (
            <p className="m-0 text-[13px] text-muted">La canceló un cierre. Para recuperarla, quita el cierre en Editar horario.</p>
          ) : (
            <Btn variant="accent" block disabled={busy} onClick={() => void call('restore_session', { p_session: session.id }, 'Clase recuperada')}>
              Recuperar esta clase
            </Btn>
          )}
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          <span className="font-mono text-[11px] uppercase tracking-[0.06em] text-muted">Solo este día</span>
          <div className="grid grid-cols-2 gap-3">
            <label className={labelCls}>
              Aforo
              <input className={inputCls} type="number" min={Math.max(1, row.booked_count)} max={500} value={cap} onChange={(e) => setCap(Number(e.target.value))} />
            </label>
            <label className={labelCls}>
              Lugar
              <input className={inputCls} value={place} onChange={(e) => setPlace(e.target.value)} />
            </label>
          </div>
          <label className={labelCls}>
            Profesor sustituto
            <select className={inputCls} value={sub} onChange={(e) => setSub(e.target.value)}>
              <option value="">{regular ? `Sin sustituto (da la clase ${regular.name})` : 'Sin sustituto'}</option>
              {app.coaches.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
          <Btn
            variant="accent"
            block
            disabled={busy || !changed || cap < row.booked_count}
            onClick={() =>
              void call(
                'update_session',
                {
                  p_session: session.id,
                  p_capacity: cap !== row.capacity ? cap : null,
                  p_substitute: sub || null,
                  p_clear_substitute: !sub && !!row.substitute_coach_profile_id,
                  p_place: place.trim() !== row.place ? place.trim() : null,
                },
                'Clase de este día actualizada',
              )
            }
          >
            Guardar cambios de este día
          </Btn>

          {confirmCancel ? (
            <div className="flex flex-col gap-2 rounded-2xl bg-err-bg p-3 text-err-fg">
              <label className="flex flex-col gap-1 text-[13px] font-semibold">
                Motivo (lo verán los alumnos)
                <input className={inputCls} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Profesor de viaje" />
              </label>
              {row.booked_count > 0 && (
                <span className="text-[13px]">
                  {row.booked_count} {row.booked_count === 1 ? 'alumno tiene' : 'alumnos tienen'} reserva: la verán cancelada y no les gastará clase.
                </span>
              )}
              <div className="flex gap-2">
                <button
                  type="button"
                  disabled={busy}
                  onClick={() => void call('cancel_session', { p_session: session.id, p_reason: reason.trim() || null }, 'Clase cancelada')}
                  className="h-11 rounded-full border-0 bg-err-fg px-4 text-[14px] font-semibold text-bg"
                >
                  Cancelar la clase
                </button>
                <button type="button" onClick={() => setConfirmCancel(false)} className="h-11 rounded-full border-0 bg-transparent px-4 text-[14px] font-semibold text-err-fg">
                  Volver
                </button>
              </div>
            </div>
          ) : (
            <button type="button" onClick={() => setConfirmCancel(true)} className="self-start border-0 bg-transparent py-1 text-[14px] font-semibold text-err-fg">
              Cancelar la clase de este día
            </button>
          )}
        </div>
      )}

      {error && (
        <p role="alert" className="m-0 rounded-2xl bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
          {error}
        </p>
      )}

      <div className="mt-2 flex flex-col gap-2 border-t border-line pt-3">
        <Btn variant="soft" block onClick={() => nav(`/staff?sesion=${encodeURIComponent(session.id)}`)}>
          Pasar lista
        </Btn>
        {row?.template_id && (
          <Btn variant="ghost" block onClick={() => nav(`/staff/horario/editor?plantilla=${row.template_id}`)}>
            Editar la clase semanal (todos los {['domingos', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábados'][session.start.getDay()]})
          </Btn>
        )}
      </div>
    </Sheet>
  )
}

/** Clase puntual desde el horario (carga las disciplinas) */
export function OneOffFromSchedule({ date, onClose }: { date: string; onClose: () => void }) {
  const app = useApp()
  const [disciplines, setDisciplines] = useState<DbDiscipline[] | null>(null)
  useEffect(() => {
    if (!supabase || !app.gymId) return
    supabase
      .from('disciplines')
      .select('id, name, kind, sort')
      .eq('gym_id', app.gymId)
      .order('sort')
      .then(({ data }) => setDisciplines((data ?? []) as DbDiscipline[]))
  }, [app.gymId])
  if (!disciplines || !app.gymId) return null
  return (
    <OneOffSheet
      gymId={app.gymId}
      disciplines={disciplines}
      initialDate={date}
      onClose={onClose}
      onSaved={async (msg) => {
        await app.reloadSchedule()
        app.toast(msg)
        onClose()
      }}
    />
  )
}

/** Eliminar la clase de un día desde el horario */
export function DeleteSessionSheet({ session, onClose }: { session: Session; onClose: () => void }) {
  const app = useApp()
  const t = app.template(session.templateId)
  const weekly = !session.templateId.startsWith('puntual:')
  const booked = session.bookedCount ?? 0
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const go = async () => {
    setBusy(true)
    setError(null)
    const { data, error } = await supabase!.rpc('delete_session', { p_session: session.id })
    setBusy(false)
    if (error) return setError(error.message)
    await app.reloadSchedule()
    app.toast(data === 'deleted' ? 'Clase eliminada' : 'Clase quitada de ese día')
    onClose()
  }

  return (
    <Sheet open onClose={onClose} title="Eliminar clase">
      <p className="m-0 text-[15px]">
        ¿Quitar <b>{t.name}</b> del {mediumDay(session.start)} a las {hhmm(session.start)}?
        {weekly ? ' Solo ese día: las demás semanas siguen igual.' : ''}
        {booked > 0 ? ` Tiene ${booked} ${booked === 1 ? 'reserva' : 'reservas'}: los alumnos la verán cancelada.` : ''}
      </p>
      {weekly && <p className="m-0 text-[13px] text-muted">Para quitarla de todas las semanas, usa la papelera en Clases y cierres.</p>}
      {error && (
        <p role="alert" className="m-0 rounded-2xl bg-err-bg px-4 py-3 text-[14px] font-medium text-err-fg">
          {error}
        </p>
      )}
      <div className="flex gap-2">
        <button type="button" disabled={busy} onClick={() => void go()} className="h-12 flex-1 rounded-[12px] border-0 bg-err-fg text-[15px] font-semibold text-bg disabled:opacity-50">
          {busy ? 'Eliminando…' : 'Eliminar'}
        </button>
        <Btn variant="soft" onClick={onClose}>
          Cancelar
        </Btn>
      </div>
    </Sheet>
  )
}
