import { useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router'
import { Screen } from '../../components/Layout'
import { Avatar, Btn, Card, Chip, Eyebrow, FilterChip, Title, cx } from '../../components/ui'
import { IconCheck, IconWifiOff } from '../../components/icons'
import { BELT_LABEL, classTitle } from '../../lib/data'
import { hhmm, longDay, ymd } from '../../lib/dates'
import { activeBookings, initials, isPresent } from '../../lib/logic'
import { loadRoster, loadSessionAttendance, subscribeAttendance, type AttendeeRow } from '../../lib/remote'
import { effectivePresence } from '../../lib/offlineQueue'
import { useAvatarUrls } from '../../lib/avatars'
import { useApp } from '../../lib/store'
import { supabase } from '../../lib/supabase'
import type { Member, Session } from '../../lib/types'

const norm = (s: string) => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()

function beltLine(m: Member) {
  if (m.rankUnknown) return 'Cinturón sin indicar'
  const stripes = m.stripes ? ` · ${m.stripes} ${m.stripes === 1 ? 'grado' : 'grados'}` : ''
  return `${BELT_LABEL[m.belt]}${stripes}${m.readyToPromote ? ' · lista para graduar' : ''}`
}

/** Elige la clase en curso o la siguiente de hoy; si no hay, la última */
function defaultSession(sessions: Session[], now: Date): Session | undefined {
  return sessions.find((s) => s.end > now) ?? sessions[sessions.length - 1]
}

/** Pasar lista (profesor). Funciona sin conexión: los cambios quedan en cola. */
export function RollCall() {
  const app = useApp()
  const [params, setParams] = useSearchParams()
  const [q, setQ] = useState('')

  const fromParam = params.get('sesion') ? app.sessionById(params.get('sesion')!) : undefined
  const day = fromParam ? fromParam.start : app.now
  const sessions = app.sessionsOn(day)
  const session = fromParam ?? defaultSession(sessions, app.now)

  // Modo real: la lista sale de las reservas del servidor (RLS: solo personal)
  const live = app.scheduleSource === 'live'
  const [liveRoster, setLiveRoster] = useState<Member[] | null>(null)
  const [rosterError, setRosterError] = useState(false)
  const sid = session?.id
  const bookedNow = session?.bookedCount
  useEffect(() => {
    if (!live || !sid) return
    let cancelled = false
    loadRoster(sid)
      .then((rows) => {
        if (cancelled) return
        setRosterError(false)
        setLiveRoster(rows.map((r) => ({ id: r.profileId, name: r.name, belt: 'blanco', stripes: 0, plan: 'black', rankUnknown: true, avatarPath: r.avatarPath })))
      })
      .catch(() => !cancelled && setRosterError(true))
    return () => {
      cancelled = true
    }
  }, [live, sid, bookedNow, app.syncVersion])

  // Asistencias confirmadas por el servidor (y avisos en tiempo real)
  const [serverAttendance, setServerAttendance] = useState<AttendeeRow[]>([])
  useEffect(() => {
    if (!live || !sid) return
    let cancelled = false
    const load = () =>
      loadSessionAttendance(sid)
        .then((rows) => !cancelled && setServerAttendance(rows))
        .catch(() => {
          /* sin red: se mantiene lo último conocido */
        })
    void load()
    const unsubscribe = subscribeAttendance(sid, () => void load())
    return () => {
      cancelled = true
      unsubscribe()
    }
  }, [live, sid, app.syncVersion])

  const livePresent = useMemo(
    () => (sid ? effectivePresence(serverAttendance.map((a) => a.profileId), app.queuedOps, sid) : new Set<string>()),
    [serverAttendance, app.queuedOps, sid],
  )
  const isHere = (pid: string) => (live ? livePresent.has(pid) : !!session && isPresent(app.state.attendance, session.id, pid))
  const toggle = (pid: string) => {
    if (!session) return
    if (live) app.markAttendance(session.id, pid, !livePresent.has(pid))
    else app.toggleAttendance(session.id, pid)
  }
  const pendingHere = live && sid ? app.queuedOps.filter((o) => o.kind !== 'code' && o.sessionId === sid).length : 0

  const roster = useMemo(() => {
    if (!session) return []
    if (live) {
      const booked = (liveRoster ?? []).map((member) => ({ member, walkIn: false }))
      // Quien fichó sin reserva (o lo marcó el profesor) también aparece
      const extra = serverAttendance
        .filter((a) => !booked.some((b) => b.member.id === a.profileId))
        .map((a) => ({
          member: { id: a.profileId, name: a.name, belt: 'blanco', stripes: 0, plan: 'black', rankUnknown: true, avatarPath: a.avatarPath } as Member,
          walkIn: true,
        }))
      return [...booked, ...extra].sort((a, b) => a.member.name.localeCompare(b.member.name, 'es'))
    }
    const booked = activeBookings(app.state.bookings, session.id)
      .filter((b) => b.status === 'booked')
      .map((b) => ({ member: app.member(b.profileId)!, walkIn: false }))
    const walkIns = (app.state.walkIns[session.id] ?? []).map((id) => ({ member: app.member(id)!, walkIn: true }))
    const seen = new Set<string>()
    return [...booked, ...walkIns]
      .filter((r) => r.member && !seen.has(r.member.id) && seen.add(r.member.id))
      .sort((a, b) => a.member.name.localeCompare(b.member.name, 'es'))
  }, [app, session, live, liveRoster, serverAttendance])

  // Cinturones reales de la sede (para la línea bajo cada nombre)
  const [ranks, setRanks] = useState<Record<string, { belt: Member['belt']; stripes: number }>>({})
  useEffect(() => {
    if (!live || !app.gymId || !supabase) return
    let cancelled = false
    supabase.rpc('gym_roster', { p_gym: app.gymId }).then(({ data }) => {
      if (cancelled || !data) return
      const m: Record<string, { belt: Member['belt']; stripes: number }> = {}
      for (const r of data as { profile_id: string; belt: Member['belt'] | null; stripes: number | null }[]) if (r.belt) m[r.profile_id] = { belt: r.belt, stripes: r.stripes ?? 0 }
      setRanks(m)
    })
    return () => {
      cancelled = true
    }
  }, [live, app.gymId])
  const withRank = (m: Member): Member => (ranks[m.id] ? { ...m, ...ranks[m.id], rankUnknown: false } : m)

  const avatarUrls = useAvatarUrls([...(liveRoster ?? []).map((m) => m.avatarPath), ...serverAttendance.map((a) => a.avatarPath)])

  if (!session) {
    return (
      <Screen top={60}>
        <Title size={44}>Pasar lista</Title>
        <p className="m-0 text-[15px] text-muted">Hoy no hay clases programadas.</p>
      </Screen>
    )
  }

  const t = app.template(session.templateId)
  const present = roster.filter((r) => isHere(r.member.id)).length
  const cur = app.curriculumFor(session.templateId)
  const note = app.state.sessionNotes[session.id]
  const filtered = q ? roster.filter((r) => norm(r.member.name).includes(norm(q))) : roster
  // Añadir sin reserva llega con el check-in real (paso 4)
  const addable = !live && q.trim().length >= 2 ? app.members.filter((m) => norm(m.name).includes(norm(q)) && !roster.some((r) => r.member.id === m.id)).slice(0, 4) : []

  return (
    <Screen top={60} gap={12}>
      <div className="flex items-end justify-between gap-3">
        <div className="flex flex-col gap-[2px]">
          <Title size={44}>Pasar lista</Title>
          <p className="m-0 text-[14px] text-muted">
            {classTitle(t)} · {hhmm(session.start)}
          </p>
        </div>
        <div className="flex items-baseline gap-1" aria-label={`${present} presentes de ${roster.length}`}>
          <span className="text-[40px] font-bold leading-none tracking-[-0.03em]">{present}</span>
          <span className="text-[14px] text-muted">de {roster.length}</span>
        </div>
      </div>

      {sessions.length > 1 && (
        <div className="no-scrollbar -mx-5 flex gap-2 overflow-x-auto px-5">
          {sessions.map((s) => {
            const st = app.template(s.templateId)
            return (
              <FilterChip key={s.id} active={s.id === session.id} onClick={() => setParams({ sesion: s.id })}>
                {hhmm(s.start)} {st.name}
              </FilterChip>
            )
          })}
        </div>
      )}
      {fromParam && ymd(fromParam.start) !== ymd(app.now) && <p className="m-0 text-[13px] text-muted">{longDay(fromParam.start)}</p>}

      {live && pendingHere > 0 ? (
        <div role="status" className="flex items-center gap-2 rounded-[14px] bg-warn-bg px-[14px] py-[10px] text-[13px] font-medium text-warn-fg">
          <IconWifiOff size={18} />
          {app.syncOffline
            ? `Sin conexión · ${pendingHere === 1 ? '1 cambio se enviará' : `${pendingHere} cambios se enviarán`} al volver la red`
            : `Enviando ${pendingHere === 1 ? '1 cambio' : `${pendingHere} cambios`}…`}
        </div>
      ) : !live && !app.online ? (
        <div role="status" className="flex items-center gap-2 rounded-[14px] bg-warn-bg px-[14px] py-[10px] text-[13px] font-medium text-warn-fg">
          <IconWifiOff size={18} />
          Sin conexión · {app.state.pendingSync === 1 ? '1 cambio se enviará' : `${app.state.pendingSync} cambios se enviarán`} al volver la red
        </div>
      ) : null}

      <div className="flex flex-col gap-1">
        <label htmlFor="buscar" className="text-[12px] font-semibold text-muted">
          Buscar o añadir alumno
        </label>
        <input
          id="buscar"
          type="search"
          placeholder="Nombre"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          className="h-[46px] rounded-[14px] border-[1.5px] border-border bg-bg px-[14px] text-[15px] text-ink placeholder:text-muted"
        />
      </div>

      <div className="flex flex-col">
        {filtered.map(({ member: m, walkIn }, i) => {
          const on = isHere(m.id)
          return (
            <div key={m.id} className={cx('flex items-center gap-3 py-[9px]', (i < filtered.length - 1 || addable.length > 0) && 'border-b border-line')}>
              <Avatar text={initials(m.name)} src={m.avatarPath ? avatarUrls[m.avatarPath] : null} />
              <div className="flex min-w-0 flex-1 flex-col gap-[2px]">
                <span className="truncate text-[15px] font-semibold">{m.name}</span>
                <span className="text-[12px] text-muted">{beltLine(withRank(m))}</span>
              </div>
              {m.debt && <Chip tone="err" small>Cuota pendiente</Chip>}
              {m.trial && <Chip tone="accent" small>Clase de prueba</Chip>}
              {walkIn && <Chip tone="neutral" small>Sin reserva</Chip>}
              <button
                aria-label={`${m.name}, ${on ? 'presente' : 'sin marcar'}`}
                aria-pressed={on}
                onClick={() => toggle(m.id)}
                className={cx(
                  'flex h-[46px] w-[46px] shrink-0 items-center justify-center rounded-full border-2',
                  on ? 'border-ink bg-ink text-on-ink' : 'border-off bg-bg text-off',
                )}
              >
                <IconCheck size={22} />
              </button>
            </div>
          )
        })}
        {addable.map((m) => (
          <div key={m.id} className="flex items-center gap-3 border-b border-line py-[9px] last:border-0">
            <Avatar text={initials(m.name)} tone="grey" />
            <div className="flex flex-1 flex-col gap-[2px]">
              <span className="text-[15px] font-semibold">{m.name}</span>
              <span className="text-[12px] text-muted">Sin reserva en esta clase</span>
            </div>
            <Btn
              size="sm"
              variant="outline"
              onClick={() => {
                app.addWalkIn(session.id, m.id)
                setQ('')
              }}
            >
              Añadir
            </Btn>
          </div>
        ))}
        {rosterError && <p role="alert" className="m-0 py-4 text-[14px] text-err-fg">No se pudo cargar la lista de la clase.</p>}
        {!rosterError && filtered.length === 0 && addable.length === 0 && (
          <p className="m-0 py-4 text-[14px] text-muted">
            {q ? 'Nadie con ese nombre.' : live && liveRoster === null ? 'Cargando…' : 'Nadie ha reservado esta clase todavía.'}
          </p>
        )}
      </div>

      {cur.curriculum && (
        <Card className="gap-2 p-4">
          <Eyebrow>{note ? 'Registrado' : 'Hoy toca'}</Eyebrow>
          <span className="text-[15px] font-semibold leading-[1.35]">{note ?? cur.unit}</span>
          <span className="text-[13px] text-muted">
            {cur.curriculum.name} · semana {cur.week} de {cur.curriculum.weeks}
          </span>
          {!note && (
            <Btn
              size="sm"
              variant="ink"
              className="mt-1 self-start"
              onClick={() => {
                app.confirmUnit(session.id, cur.unit!)
                app.toast('Clase registrada en el currículo')
              }}
            >
              Confirmar lo dado
            </Btn>
          )}
        </Card>
      )}
    </Screen>
  )
}
