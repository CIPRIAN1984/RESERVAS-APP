/**
 * Estado de la app del prototipo, persistido en localStorage.
 * Es la capa que se sustituirá por Supabase (TanStack Query + RPC).
 * Las pantallas solo usan `useApp()`, así que el cambio queda aislado aquí.
 */
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { ASSIGNMENTS, COACHES, CURRICULA, INITIAL_VIDEO_PROGRESS, ME, ME_ID, MEMBERS, PLANS, TEMPLATES } from './data'
import { addDays, startOfWeek, ymd } from './dates'
import { supabase } from './supabase'
import { checkInByCode, loadMyBookings, loadPlanStatus, loadSchedule, rpcBook, rpcCancel, sendQueuedOp, sessionFromRow, subscribeSchedule, type BookOutcome, type CodeCheckIn, type RemoteSchedule } from './remote'
import { newClientId, OfflineQueue, type KeyValueStore, type QueuedOp } from './offlineQueue'
import { useAuth } from '../features/auth/AuthProvider'
import {
  bookSession,
  bookedCount,
  waitlist,
  cancelBooking,
  findBooking,
  isPresent,
  parseSessionId,
  recordAttendance,
  removeAttendance,
  seedBookingsFor,
  sessionsForDate,
  sessionsForRange,
} from './logic'
import type { Attendance, Booking, ClassTemplate, Coach, Curriculum, CurriculumAssignment, Member, Plan, PlanStatus, Session } from './types'

// v2: horario real de ITACA (los datos de la v1 usaban clases inventadas)
const STORAGE_KEY = 'itaca-app-state-v2'
/** Días que se generan por delante desde el lunes de esta semana */
// Las clases se crean con 12 semanas (tres meses) de antelación
const WINDOW_DAYS = 84

export type Role = 'student' | 'staff'

export interface AppState {
  version: 1
  bookings: Booking[]
  seeded: string[]
  attendance: Attendance[]
  /** Cambios de asistencia hechos sin conexión, pendientes de enviar */
  pendingSync: number
  walkIns: Record<string, string[]>
  itacaPlus: boolean
  videoProgress: Record<string, number>
  assignments: CurriculumAssignment[]
  substitutes: Record<string, string>
  /** Qué se dio realmente en cada sesión (session_notes) */
  sessionNotes: Record<string, string>
  requestedPlan?: string
  /** Foto de perfil en modo demo (dataURL reducida) */
  demoAvatar?: string
  /** Datos de perfil editados en modo demo */
  demoProfile?: DemoProfile
}

export interface DemoProfile {
  name: string
  belt: Member['belt']
  stripes: number
  rankSince: string | null
  birthDate: string | null
  phone: string | null
  emergencyName: string | null
  emergencyPhone: string | null
}

function freshState(): AppState {
  return {
    version: 1,
    bookings: [],
    seeded: [],
    attendance: [],
    pendingSync: 0,
    walkIns: {},
    itacaPlus: true,
    videoProgress: { ...INITIAL_VIDEO_PROGRESS },
    assignments: ASSIGNMENTS.map((a) => ({ ...a })),
    substitutes: {},
    sessionNotes: {},
  }
}

function load(): AppState | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as AppState
    return parsed.version === 1 ? parsed : null
  } catch {
    return null
  }
}

function save(s: AppState) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(s))
  } catch {
    /* sin almacenamiento: la app sigue funcionando en memoria */
  }
}

const templateById = new Map(TEMPLATES.map((t) => [t.id, t]))

/** Añade reservas de ejemplo a las sesiones de la ventana que aún no las tengan */
function ensureSeeded(
  s: AppState,
  now: Date,
  isNew: boolean,
  sessions: Session[] = sessionsForRange(TEMPLATES, startOfWeek(now), WINDOW_DAYS),
  tpl: (id: string) => ClassTemplate | undefined = (id) => templateById.get(id),
): AppState {
  const seeded = new Set(s.seeded)
  const extra: Booking[] = []
  for (const session of sessions) {
    if (seeded.has(session.id)) continue
    const t = tpl(session.templateId)
    if (!t) continue
    extra.push(...seedBookingsFor(session, t, MEMBERS, ME_ID))
    seeded.add(session.id)
  }
  let bookings = extra.length ? [...s.bookings, ...extra] : s.bookings
  if (isNew) {
    // El alumno de ejemplo arranca con su próxima clase de Gi reservada
    const next = sessions.find((x) => !tpl(x.templateId)?.kidsOnly && x.end > now && x.start.getHours() >= 17)
    if (next) bookings = [...bookings, { id: 'me-first', sessionId: next.id, profileId: ME_ID, status: 'booked', createdAt: now.getTime() }]
  }
  if (!extra.length && !isNew) return s
  return { ...s, bookings, seeded: [...seeded] }
}

export interface Toast {
  id: number
  text: string
}

interface AppApi {
  state: AppState
  now: Date
  online: boolean
  me: Member
  members: Member[]
  coaches: Coach[]
  curricula: Curriculum[]
  templates: ClassTemplate[]
  /** Catálogo de tarifas */
  plans: Plan[]
  /** Mi tarifa vigente (con servidor: la que asigna recepción) */
  myPlan: Plan | null
  /** Con servidor: mi tarifa y las clases usadas en el periodo (null = sin tarifa asignada) */
  planStatus: PlanStatus | null
  /** ITACA+ activo (con servidor: asignado por recepción y con tarifa mensual en vigor) */
  itacaPlus: boolean
  template: (id: string) => ClassTemplate
  coach: (id: string | null) => Coach | undefined
  member: (id: string) => Member | undefined
  sessionsOn: (d: Date) => Session[]
  sessionById: (id: string) => Session | undefined
  myBooking: (sessionId: string) => Booking | undefined
  /** Plazas ocupadas y lista de espera de una sesión */
  occupancy: (s: Session) => { booked: number; waiting: number }
  coachFor: (s: Session) => Coach | undefined
  curriculumFor: (templateId: string) => { curriculum: Curriculum | null; week: number; unit: string | null }
  book: (s: Session) => Promise<BookOutcome>
  cancel: (s: Session) => Promise<void>
  /** Mis reservas activas próximas (modo real: del servidor) */
  myUpcoming: () => { booking: Booking; session: Session }[]
  checkIn: (s: Session) => void
  toggleAttendance: (sessionId: string, profileId: string) => void
  addWalkIn: (sessionId: string, profileId: string) => void
  confirmUnit: (sessionId: string, unit: string) => void
  assignCurriculum: (templateId: string, curriculumId: string | null) => void
  setSubstitute: (sessionId: string, coachId: string) => void
  setVideoProgress: (videoId: string, pct: number) => void
  setItacaPlus: (v: boolean) => void
  requestPlan: (name: string) => void
  setDemoAvatar: (dataUrl: string | undefined) => void
  setDemoProfile: (p: DemoProfile) => void
  reset: () => void
  toast: (text: string) => void
  toasts: Toast[]
  /** 'live' = horario leído de Supabase; 'demo' = datos de ejemplo */
  scheduleSource: 'demo' | 'live'
  scheduleLoading: boolean
  scheduleError: string | null
  gymId: string | null
  reloadSchedule: () => Promise<void>
  // ---------- Asistencia con cola sin conexión (modo real) ----------
  /** Operaciones pendientes de enviar */
  queuedOps: readonly QueuedOp[]
  /** El último intento de envío falló por falta de red */
  syncOffline: boolean
  markAttendance: (sessionId: string, profileId: string, present: boolean) => void
  checkInWithCode: (code: string) => Promise<CodeCheckIn>
  flushQueue: () => Promise<void>
  /** Aumenta cada vez que se envían cambios: las pantallas lo usan para releer del servidor */
  syncVersion: number
}

const Ctx = createContext<AppApi | null>(null)

let idCounter = 0
const newId = () => `${Date.now().toString(36)}-${(idCounter++).toString(36)}-${Math.random().toString(36).slice(2, 7)}`

export function AppProvider({ children, initialNow }: { children: ReactNode; initialNow?: Date }) {
  const [now, setNow] = useState(() => initialNow ?? new Date())
  const [state, setState] = useState<AppState>(() => {
    const stored = load()
    return ensureSeeded(stored ?? freshState(), initialNow ?? new Date(), !stored)
  })
  const [online, setOnline] = useState(() => (typeof navigator === 'undefined' ? true : navigator.onLine))
  const [toasts, setToasts] = useState<Toast[]>([])
  const toastId = useRef(0)

  // ---------- Horario desde Supabase ----------
  const auth = useAuth()
  const gymId = auth.mode === 'live' && auth.session ? (auth.memberships[0]?.gymId ?? null) : null
  const [remote, setRemote] = useState<RemoteSchedule | null>(null)
  const [scheduleLoading, setScheduleLoading] = useState(false)
  const [scheduleError, setScheduleError] = useState<string | null>(null)

  const reloadSchedule = useCallback(async () => {
    if (!gymId) {
      setRemote(null)
      return
    }
    setScheduleLoading(true)
    try {
      const today = new Date()
      const from = addDays(startOfWeek(today), -7)
      const r = await loadSchedule(gymId, from, addDays(from, 7 + WINDOW_DAYS + 7))
      setRemote(r)
      setScheduleError(null)
    } catch (e) {
      setScheduleError(e instanceof Error ? e.message : 'No se pudo cargar el horario')
    } finally {
      setScheduleLoading(false)
    }
  }, [gymId])

  useEffect(() => {
    void reloadSchedule()
  }, [reloadSchedule])

  // Tiempo real: ocupación de las clases y cambios en mis reservas (p. ej. subir de la lista de espera)
  const remoteRange = useRef<{ from: Date; to: Date } | null>(null)
  useEffect(() => {
    if (!gymId) return
    const from = addDays(startOfWeek(new Date()), -7)
    remoteRange.current = { from, to: addDays(from, 7 + WINDOW_DAYS + 7) }
    let timer: ReturnType<typeof setTimeout> | null = null
    const unsubscribe = subscribeSchedule(
      gymId,
      (row) =>
        setRemote((r) =>
          r ? { ...r, sessions: r.sessions.map((x) => (x.id === row.id ? { ...x, ...sessionFromRow(row) } : x)) } : r,
        ),
      () => {
        if (timer) clearTimeout(timer)
        timer = setTimeout(async () => {
          const range = remoteRange.current
          if (!range) return
          try {
            const mine = await loadMyBookings(range.from, range.to)
            setRemote((r) => (r ? { ...r, myBookings: mine } : r))
          } catch {
            /* se reintentará con el siguiente cambio */
          }
        }, 300)
      },
    )
    return () => {
      if (timer) clearTimeout(timer)
      unsubscribe()
    }
  }, [gymId])

  // Mi tarifa y lo que llevo gastado: se relee cada vez que cambian mis reservas
  const [planStatus, setPlanStatus] = useState<PlanStatus | null>(null)
  const [itacaLive, setItacaLive] = useState(false)
  const myBookingsList = remote?.myBookings
  useEffect(() => {
    if (!gymId || !myBookingsList) {
      setPlanStatus(null)
      return
    }
    let cancelled = false
    loadPlanStatus()
      .then((p) => !cancelled && setPlanStatus(p))
      .catch(() => undefined)
    supabase!
      .rpc('has_itaca_plus')
      .then(({ data }) => !cancelled && setItacaLive(data === true))
    return () => {
      cancelled = true
    }
  }, [gymId, myBookingsList])

  const refreshMine = useCallback(async () => {
    const range = remoteRange.current
    if (!range) return
    const mine = await loadMyBookings(range.from, range.to)
    setRemote((r) => (r ? { ...r, myBookings: mine } : r))
  }, [])

  useEffect(() => save(state), [state])

  useEffect(() => {
    if (initialNow) return
    const t = setInterval(() => setNow(new Date()), 30000)
    return () => clearInterval(t)
  }, [initialNow])

  useEffect(() => {
    setState((s) => ensureSeeded(s, now, false))
  }, [now])

  useEffect(() => {
    const on = () => setOnline(true)
    const off = () => setOnline(false)
    window.addEventListener('online', on)
    window.addEventListener('offline', off)
    return () => {
      window.removeEventListener('online', on)
      window.removeEventListener('offline', off)
    }
  }, [])

  const toast = useCallback((text: string) => {
    const id = ++toastId.current
    setToasts((t) => [...t, { id, text }])
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 3200)
  }, [])

  // Al volver la red se envían los cambios en cola
  useEffect(() => {
    if (online && state.pendingSync > 0) {
      const n = state.pendingSync
      setState((s) => ({ ...s, pendingSync: 0 }))
      toast(n === 1 ? '1 cambio sincronizado' : `${n} cambios sincronizados`)
    }
  }, [online, state.pendingSync, toast])

  // ---------- Cola sin conexión ----------
  const userId = auth.mode === 'live' ? auth.session?.user.id ?? null : null
  const offlineQueue = useMemo(() => {
    if (!userId) return null
    let storage: KeyValueStore | null = null
    try {
      storage = window.localStorage
    } catch {
      storage = null
    }
    return new OfflineQueue(`itaca-cola-${userId}`, storage, sendQueuedOp)
  }, [userId])
  // Cambia con cada operación encolada o enviada: hace que la pantalla vea la cola actual
  const [queueVersion, setQueueVersion] = useState(0)
  const [syncOffline, setSyncOffline] = useState(false)
  const [syncVersion, setSyncVersion] = useState(0)
  useEffect(() => offlineQueue?.subscribe(() => setQueueVersion((v) => v + 1)), [offlineQueue])

  const flushQueue = useCallback(async () => {
    if (!offlineQueue || offlineQueue.pending().length === 0) return
    const wasOffline = syncOffline
    const r = await offlineQueue.flush()
    setSyncOffline(r.offline)
    // Lo enviado ya está en el servidor: que las pantallas relean (el tiempo real pudo perderse sin red)
    if (r.sent > 0 || r.dropped.length > 0) setSyncVersion((v) => v + 1)
    for (const d of r.dropped) toast(`No se guardó un cambio: ${d.message}`)
    if (wasOffline && !r.offline && r.sent > 0) toast(r.sent === 1 ? '1 cambio enviado' : `${r.sent} cambios enviados`)
  }, [offlineQueue, syncOffline, toast])

  useEffect(() => {
    if (!offlineQueue) return
    void flushQueue()
    const onOnline = () => void flushQueue()
    window.addEventListener('online', onOnline)
    const t = setInterval(() => {
      if (offlineQueue.pending().length) void flushQueue()
    }, 10000)
    return () => {
      window.removeEventListener('online', onOnline)
      clearInterval(t)
    }
  }, [offlineQueue, flushQueue])

  // Relee la ocupación de una sesión (por si el tiempo real tarda)
  const reloadSession = useCallback(async (id: string) => {
    if (!supabase) return
    const { data } = await supabase.from('class_sessions').select('id, booked_count, waitlist_count, status, cancel_reason').eq('id', id).maybeSingle()
    if (data) setRemote((r) => (r ? { ...r, sessions: r.sessions.map((x) => (x.id === id ? { ...x, ...sessionFromRow(data as never) } : x)) } : r))
  }, [])

  const api = useMemo<AppApi>(() => {
    const templates = remote?.templates ?? TEMPLATES
    const tmap = remote ? new Map(remote.templates.map((t) => [t.id, t])) : templateById
    const coaches = remote?.coaches ?? COACHES
    const template = (id: string) => tmap.get(id)!
    const coach = (id: string | null) => (id ? coaches.find((c) => c.id === id) : undefined)
    const member = (id: string) => MEMBERS.find((m) => m.id === id)
    const sessionsOn = (d: Date) => {
      if (!remote) return sessionsForDate(TEMPLATES, d)
      const day = ymd(d)
      return remote.sessions.filter((s) => s.date === day)
    }
    const sessionById = (id: string) => {
      if (remote) return remote.sessions.find((s) => s.id === id)
      const { date } = parseSessionId(id)
      if (!date) return undefined
      const [y, m, day] = date.split('-').map(Number)
      return sessionsForDate(TEMPLATES, new Date(y, m - 1, day)).find((s) => s.id === id)
    }
    const coachFor = (s: Session) => coach(state.substitutes[s.id] ?? s.coachId)
    const curriculumFor = (templateId: string) => {
      const a = state.assignments.find((x) => x.templateId === templateId)
      const curriculum = a?.curriculumId ? CURRICULA.find((c) => c.id === a.curriculumId) ?? null : null
      const week = a?.week ?? 1
      return { curriculum, week, unit: curriculum ? curriculum.units[Math.min(week, curriculum.units.length) - 1] : null }
    }
    const queue = (s: AppState): AppState => (online ? s : { ...s, pendingSync: s.pendingSync + 1 })

    return {
      state,
      now,
      online,
      // Yo: con sesión iniciada, nombre y cinturón reales; en demo, el perfil de ejemplo (editable)
      me:
        auth.mode === 'live' && auth.profile
          ? { ...ME, name: auth.profile.fullName, belt: auth.rank?.belt ?? 'blanco', stripes: auth.rank?.stripes ?? 0, rankUnknown: !auth.rank }
          : state.demoProfile
            ? { ...ME, name: state.demoProfile.name, belt: state.demoProfile.belt, stripes: state.demoProfile.stripes }
            : ME,
      members: MEMBERS,
      coaches,
      curricula: CURRICULA,
      templates,
      plans: remote?.plans ?? PLANS,
      myPlan: remote ? (planStatus ? remote.plans.find((p) => p.dbId === planStatus.planId) ?? null : null) : PLANS.find((p) => p.id === ME.plan) ?? null,
      planStatus,
      itacaPlus: remote ? itacaLive : state.itacaPlus,
      template,
      coach,
      member,
      sessionsOn,
      sessionById,
      myBooking: (sid) =>
        remote
          ? remote.myBookings.find((b) => b.sessionId === sid && b.profileId === remote.myProfileId)
          : findBooking(state.bookings, sid, ME_ID),
      occupancy: (s) =>
        remote
          ? { booked: s.bookedCount ?? 0, waiting: s.waitlistCount ?? 0 }
          : { booked: bookedCount(state.bookings, s.id), waiting: waitlist(state.bookings, s.id).length },
      myUpcoming: () => {
        if (remote) {
          return remote.myBookings
            .filter((b) => b.profileId === remote.myProfileId)
            .map((b) => ({ booking: b, session: remote.sessions.find((x) => x.id === b.sessionId)! }))
            .filter((x) => x.session && x.session.end > now)
            .sort((a, b) => a.session.start.getTime() - b.session.start.getTime())
        }
        return state.bookings
          .filter((b) => b.profileId === ME_ID && b.status !== 'cancelled')
          .map((b) => ({ booking: b, session: sessionById(b.sessionId)! }))
          .filter((x) => x.session && x.session.end > now)
          .sort((a, b) => a.session.start.getTime() - b.session.start.getTime())
      },
      coachFor,
      curriculumFor,
      book: async (s) => {
        if (remote) {
          const r = await rpcBook(s.id)
          if (r.ok || r.reason === 'already') await Promise.all([refreshMine(), reloadSession(s.id)])
          return r
        }
        const r = bookSession(state.bookings, { session: s, template: template(s.templateId), member: ME, now, newId })
        if (r.ok) {
          setState((st) => ({ ...st, bookings: r.bookings }))
          return { ok: true, status: r.status, position: r.position }
        }
        return { ok: false, reason: r.reason }
      },
      cancel: async (s) => {
        if (remote) {
          const b = remote.myBookings.find((x) => x.sessionId === s.id && x.profileId === remote.myProfileId)
          if (!b) return
          const r = await rpcCancel(b.id)
          if (!r.ok) {
            toast(r.message ?? 'No se pudo cancelar')
            return
          }
          await Promise.all([refreshMine(), reloadSession(s.id)])
          if (b.status === 'waitlist') toast('Has salido de la lista de espera')
          else if (r.late) toast('Cancelación fuera de plazo: contará como no presentado')
          else toast(r.promoted ? 'Reserva cancelada. Tu plaza pasa al primero de la lista de espera' : 'Reserva cancelada')
          return
        }
        const b = findBooking(state.bookings, s.id, ME_ID)
        if (!b) return
        const wasWaitlist = b.status === 'waitlist'
        const r = cancelBooking(state.bookings, b.id, s, now)
        setState((st) => ({ ...st, bookings: r.bookings }))
        if (wasWaitlist) toast('Has salido de la lista de espera')
        else if (r.late) toast('Cancelación fuera de plazo: contará como no presentado')
        else toast(r.promotedProfileId ? 'Reserva cancelada. Tu plaza pasa al primero de la lista de espera' : 'Reserva cancelada')
      },
      checkIn: (s) => {
        setState((st) =>
          queue({
            ...st,
            attendance: recordAttendance(st.attendance, { sessionId: s.id, profileId: ME_ID, method: 'qr', clientId: newId(), at: Date.now() }),
          }),
        )
      },
      toggleAttendance: (sid, pid) => {
        setState((st) =>
          queue({
            ...st,
            attendance: isPresent(st.attendance, sid, pid)
              ? removeAttendance(st.attendance, sid, pid)
              : recordAttendance(st.attendance, { sessionId: sid, profileId: pid, method: 'coach', clientId: newId(), at: Date.now() }),
          }),
        )
      },
      addWalkIn: (sid, pid) => {
        setState((st) =>
          queue({
            ...st,
            walkIns: { ...st.walkIns, [sid]: [...(st.walkIns[sid] ?? []), pid] },
            attendance: recordAttendance(st.attendance, { sessionId: sid, profileId: pid, method: 'coach', clientId: newId(), at: Date.now() }),
          }),
        )
      },
      confirmUnit: (sid, unit) => setState((st) => queue({ ...st, sessionNotes: { ...st.sessionNotes, [sid]: unit } })),
      assignCurriculum: (tid, cid) =>
        setState((st) => {
          const exists = st.assignments.some((a) => a.templateId === tid)
          const assignments = exists
            ? st.assignments.map((a) => (a.templateId === tid ? { ...a, curriculumId: cid, week: 1 } : a))
            : [...st.assignments, { templateId: tid, curriculumId: cid, week: 1 }]
          return { ...st, assignments }
        }),
      setSubstitute: (sid, cid) => setState((st) => ({ ...st, substitutes: { ...st.substitutes, [sid]: cid } })),
      setVideoProgress: (vid, pct) => setState((st) => ({ ...st, videoProgress: { ...st.videoProgress, [vid]: pct } })),
      setItacaPlus: (v) => setState((st) => ({ ...st, itacaPlus: v })),
      requestPlan: (name) => setState((st) => ({ ...st, requestedPlan: name })),
      setDemoAvatar: (dataUrl) => setState((st) => ({ ...st, demoAvatar: dataUrl })),
      setDemoProfile: (p) => setState((st) => ({ ...st, demoProfile: p })),
      reset: () => {
        const fresh = ensureSeeded(freshState(), new Date(), true)
        setState(fresh)
      },
      toast,
      toasts,
      scheduleSource: remote ? 'live' : 'demo',
      scheduleLoading,
      scheduleError,
      gymId,
      reloadSchedule,
      // copia: un array nuevo en cada cambio de la cola
      queuedOps: offlineQueue ? [...offlineQueue.pending()] : [],
      syncOffline,
      markAttendance: (sid, pid, present) => {
        if (!offlineQueue) return
        const at = new Date().toISOString()
        offlineQueue.enqueue(
          present
            ? { kind: 'mark', clientId: newClientId(), sessionId: sid, profileId: pid, method: 'coach', at }
            : { kind: 'unmark', clientId: newClientId(), sessionId: sid, profileId: pid, at },
        )
        void flushQueue()
      },
      checkInWithCode: async (code) => {
        const clientId = newClientId()
        const at = new Date().toISOString()
        const r = await checkInByCode(code, clientId, at)
        if (r === 'network') {
          offlineQueue?.enqueue({ kind: 'code', clientId, code, at })
          setSyncOffline(true)
          return { ok: true, queued: true }
        }
        if (r.ok) void reloadSchedule()
        return r
      },
      flushQueue,
      syncVersion,
    }
  }, [auth, state, now, online, toast, toasts, remote, planStatus, itacaLive, scheduleLoading, scheduleError, gymId, reloadSchedule, refreshMine, reloadSession, offlineQueue, queueVersion, syncOffline, flushQueue, syncVersion])

  return <Ctx.Provider value={api}>{children}</Ctx.Provider>
}

export function useApp(): AppApi {
  const v = useContext(Ctx)
  if (!v) throw new Error('useApp fuera de AppProvider')
  return v
}

